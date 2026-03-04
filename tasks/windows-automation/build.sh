#!/usr/bin/env bash
# Create Windows stemcell. Three modes (one per run, preference order):
#   ISO:          Packer from ISO -> base VM -> network/updates -> clone to target -> stembuild on target.
#   template:    govc clone from template -> target VM -> network/updates -> stembuild (no Packer).
#   existing_base: govc clone from existing VM -> target VM -> network/updates -> stembuild (no Packer).
# Convention: read vars with get_var (vars-file-utils.sh); find VMs with govc helpers.

set -euo pipefail
# Script directory (must be set first so sourced libs can use it)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Common VM power helpers (shutdown, wait poweredOff, reboot via shutdown+powerOn)
VM_POWER_UTILS="$SCRIPT_DIR/scripts/vm-power-utils.sh"
[[ -f "$VM_POWER_UTILS" ]] || { echo "ERROR: vm-power-utils.sh not found: $VM_POWER_UTILS" >&2; exit 1; }
source "$VM_POWER_UTILS"

# Common logging and run_script
COMMON_SH="$SCRIPT_DIR/scripts/common.sh"
[[ -f "$COMMON_SH" ]] || { echo "ERROR: common.sh not found: $COMMON_SH" >&2; exit 1; }
source "$COMMON_SH"

# Vars file parsing (get_var <file> <key>)
VARS_UTILS="$SCRIPT_DIR/scripts/vars-file-utils.sh"
[[ -f "$VARS_UTILS" ]] || { echo "ERROR: vars-file-utils.sh not found: $VARS_UTILS" >&2; exit 1; }
source "$VARS_UTILS"

GOVC_VM_UTILS="$SCRIPT_DIR/scripts/govc-vm-utils.sh"
[[ -f "$GOVC_VM_UTILS" ]] || { echo "ERROR: govc-vm-utils.sh not found: $GOVC_VM_UTILS" >&2; exit 1; }
source "$GOVC_VM_UTILS"

# Helpers for mode branches: trim var value; export GOVC_* from vars file
trim_var() { printf '%s' "${1:-}" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
export_govc_from_vars() {
    local vf="${1:?}"
    export GOVC_URL="$(get_var "$vf" "vcenter_server")"
    export GOVC_USERNAME="$(get_var "$vf" "vcenter_username")"
    export GOVC_PASSWORD="$(get_var "$vf" "vcenter_password")"
    local inc; inc=$(get_var "$vf" "vcenter_insecure_connection")
    [[ "$inc" == "true" ]] && export GOVC_INSECURE=true
}

# Query vSphere for guest OS type matching windows_version (2019/2022/2025). Uses govc vm.option.info.
# Returns the guest OS identifier (e.g. windows2022srvNext_64Guest) or empty string if query fails.
# Caller should fall back to hardcoded defaults when this returns empty.
get_guest_os_type_from_vsphere() {
    local vars_file="${1:?}"
    local windows_version="${2:-2019}"
    [[ -f "$vars_file" ]] || return 1
    export_govc_from_vars "$vars_file"
    local dc cluster host
    dc=$(trim_var "$(get_var "$vars_file" "vcenter_datacenter")")
    cluster=$(trim_var "$(get_var "$vars_file" "vcenter_cluster")")
    host=$(trim_var "$(get_var "$vars_file" "vcenter_host")")
    [[ -n "$dc" ]] || return 1
    export GOVC_DATACENTER="$dc"
    local govc_args=(-dc "$dc")
    if [[ -n "$cluster" ]]; then
        govc_args+=(-cluster "$cluster")
    elif [[ -n "$host" ]]; then
        govc_args+=(-host "$host")
    else
        return 1
    fi
    local pattern
    case "$windows_version" in
        2025) pattern="Windows Server 2025";;
        2022) pattern="Windows Server 2022";;
        2019) pattern="Windows Server 2019";;
        *)    pattern="Windows Server 2019";;
    esac
    local line id
    # Prefer 64-bit when both 32 and 64 are listed (match line with 64 or fullName like "(64-bit)")
    line=$(govc vm.option.info "${govc_args[@]}" 2>/dev/null | grep -i "Windows Server" | grep -i "$windows_version" | grep -iE "64|64-bit" | head -1)
    [[ -z "$line" ]] && line=$(govc vm.option.info "${govc_args[@]}" 2>/dev/null | grep -i "Windows Server" | grep -i "$windows_version" | head -1)
    if [[ -n "$line" ]]; then
        # govc may print "id fullName" or "fullName id"; VMware ids look like windows2019srv_64Guest
        id=$(echo "$line" | awk '{ print $1 }')
        if [[ -z "$id" ]] || [[ ! "$id" =~ [gG]uest ]] || [[ ! "$id" =~ [wW]indows ]]; then
            id=$(echo "$line" | awk '{ print $NF }')
        fi
        # Only return if it looks like a valid vSphere guest OS identifier (avoid passing "Windows" etc.)
        if [[ -n "$id" ]] && [[ "$id" =~ [gG]uest ]] && [[ "$id" =~ [wW]indows ]]; then
            printf '%s' "$id"
        fi
    fi
    return 0
}

# Set PKR_VAR_guest_os_type once from vars_file using static mapping (Windows Server 2019/2022/2025). Call before validate/build.
# Static mapping: 2019 -> windows2019srv_64Guest, 2022 -> windows2019srvNext_64Guest, 2025 -> windows2022srvNext_64Guest.
set_packer_guest_os_type() {
    local vars_file="${1:-}"
    if [[ -z "$vars_file" ]] || [[ ! -f "$vars_file" ]]; then
        export PKR_VAR_guest_os_type="windows2019srv_64Guest"
        log_info "Guest OS type for Packer: windows2019srv_64Guest (default)"
        return 0
    fi
    local win_ver guest_id
    win_ver=$(trim_var "$(get_var "$vars_file" "windows_version")")
    win_ver="${win_ver:-2019}"
    case "$win_ver" in
        2019) guest_id="windows2019srv_64Guest";;
        2022) guest_id="windows2019srvNext_64Guest";;
        2025) guest_id="windows2022srvNext_64Guest";;
        *)    guest_id="windows2019srv_64Guest";;
    esac
    log_info "Guest OS type for Packer: $guest_id (windows_version=$win_ver)"
    export PKR_VAR_guest_os_type="$guest_id"
}

# Global variables for cleanup
CLEANUP_VM_NAME=""
CLEANUP_TARGET_VM_NAME=""
CLEANUP_PACKER_PID=""
CLEANUP_PACKER_LOG_FILE=""
CLEANUP_BUILD_MODE=""
CLEANUP_VARS_FILE=""
CLEANUP_ENABLED=false
CLEANUP_ALREADY_RAN=false

jumper_ip=""
jumper_user=""
jumper_password=""

# Cleanup function for error handling
cleanup_on_failure() {
    local exit_code=${1:-1}
    
    if [[ "$CLEANUP_ENABLED" != "true" ]]; then
        return 0
    fi
    # Run actual cleanup only once (e.g. if both ERR and EXIT fire)
    if [[ "${CLEANUP_ALREADY_RAN:-false}" == "true" ]]; then
        return 0
    fi
    CLEANUP_ALREADY_RAN=true

    # Print Packer log on failure so CI captures it (exit_code is from the trap)
    if [[ "${exit_code:-1}" -ne 0 ]] && [[ -n "${CLEANUP_PACKER_LOG_FILE:-}" ]] && [[ -f "${CLEANUP_PACKER_LOG_FILE}" ]]; then
        log_error "=========================================="
        log_error "PACKER BUILD LOG (last 1000 lines, exit code: ${exit_code:-1})"
        log_error "=========================================="
        tail -1000 "$CLEANUP_PACKER_LOG_FILE" 2>/dev/null | while IFS= read -r line; do
            log_error "  $line"
        done || log_error "  (Could not read log)"
        log_error "=========================================="
    fi

    local cleanup_mode="${CLEANUP_BUILD_MODE:-<not set>}"
    log_warn "=========================================="
    log_warn "Cleanup triggered due to failure"
    log_warn "Exit code: $exit_code"
    log_warn "Build mode: $cleanup_mode"
    log_warn "VM name: $CLEANUP_VM_NAME"
    [[ -n "$CLEANUP_TARGET_VM_NAME" ]] && log_warn "Target VM (clone): $CLEANUP_TARGET_VM_NAME"
    log_warn "=========================================="
    
    # Template mode: cleanup created VM (stop and delete)
    # Existing_base mode: cleanup only the clone (CLEANUP_TARGET_VM_NAME); never touch user's base VM
    # ISO mode: cleanup base VM and optionally target VM
    if [[ "$CLEANUP_BUILD_MODE" == "template" ]]; then
        log_warn "Template mode: Cleaning up VM (stop and delete)"
    elif [[ "$CLEANUP_BUILD_MODE" == "existing_base" ]]; then
        log_warn "Existing_base mode: Cleaning up target VM (clone) only; base VM is left unchanged"
        # Fall through to use same cleanup logic; CLEANUP_VM_NAME is empty so only CLEANUP_TARGET_VM_NAME will be cleaned
    elif [[ "$CLEANUP_BUILD_MODE" != "iso" ]]; then
        log_info "Skipping cleanup (unknown build mode: $cleanup_mode)"
        return 0
    fi
    
    # Extract vCenter credentials for cleanup
    if [[ -n "$CLEANUP_VARS_FILE" ]] && [[ -f "$CLEANUP_VARS_FILE" ]]; then
        local vcenter_server vcenter_user vcenter_pass vcenter_insecure
        vcenter_server=$(get_var "$CLEANUP_VARS_FILE" "vcenter_server")
        vcenter_user=$(get_var "$CLEANUP_VARS_FILE" "vcenter_username")
        vcenter_pass=$(get_var "$CLEANUP_VARS_FILE" "vcenter_password")
        vcenter_insecure=$(get_var "$CLEANUP_VARS_FILE" "vcenter_insecure_connection")
        
        export GOVC_URL="$vcenter_server"
        export GOVC_USERNAME="$vcenter_user"
        export GOVC_PASSWORD="$vcenter_pass"
        if [[ "$vcenter_insecure" == "true" ]]; then
            export GOVC_INSECURE=true
        fi
    fi
    
    # Stop Packer process
    if [[ -n "$CLEANUP_PACKER_PID" ]] && kill -0 "$CLEANUP_PACKER_PID" 2>/dev/null; then
        log_warn "Stopping Packer process (PID: $CLEANUP_PACKER_PID)..."
        pkill -9 "$CLEANUP_PACKER_PID" 2>/dev/null || true
    fi
    
    # Shutdown and delete VM
    if [[ -n "$CLEANUP_VM_NAME" ]]; then
        log_warn "Cleaning up VM: $CLEANUP_VM_NAME"
        
        # Check if VM exists
        if vm_exists "$CLEANUP_VM_NAME"; then
            # Power-off sequence only (no destroy here); destroy is a separate step below.
            if [[ "$(get_vm_power_state "$CLEANUP_VM_NAME")" != "poweredOff" ]]; then
                log_warn "Shutting down VM..."
                if ! vm_power_off "$CLEANUP_VM_NAME" 120 0; then
                    log_warn "VM did not power off within 120s; attempting delete anyway"
                fi
            fi
            
            # Delete VM (separate from power-off)
            log_warn "Deleting VM..."
            govc vm.destroy "$CLEANUP_VM_NAME" >/dev/null 2>&1 || {
                log_warn "Failed to delete VM (may require manual cleanup)"
            }
        else
            log_info "VM not found (may have been deleted already)"
        fi
    fi

    # Also clean up target VM (clone used for stembuild) if it was created and is different from base VM
    if [[ -n "$CLEANUP_TARGET_VM_NAME" ]] && [[ "$CLEANUP_TARGET_VM_NAME" != "$CLEANUP_VM_NAME" ]]; then
        log_warn "Cleaning up target VM (clone): $CLEANUP_TARGET_VM_NAME"
        if vm_exists "$CLEANUP_TARGET_VM_NAME"; then
            if [[ "$(get_vm_power_state "$CLEANUP_TARGET_VM_NAME")" != "poweredOff" ]]; then
                log_warn "Shutting down target VM..."
                vm_power_off "$CLEANUP_TARGET_VM_NAME" 120 0 || true
            fi
            log_warn "Deleting target VM..."
            govc vm.destroy "$CLEANUP_TARGET_VM_NAME" >/dev/null 2>&1 || {
                log_warn "Failed to delete target VM (may require manual cleanup): $CLEANUP_TARGET_VM_NAME"
            }
        else
            log_info "Target VM not found (may have been deleted already)"
        fi
    fi
    
    log_warn "Cleanup completed"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for Packer
    if ! command -v packer &> /dev/null; then
        missing_tools+=("packer")
    else
        local packer_version=$(packer version | head -n1)
        log_info "Found: $packer_version"
    fi
    
    # Check for jq (for parsing JSON)
    if ! command -v jq &> /dev/null; then
        log_warn "jq not found (optional, used for parsing manifests)"
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Display variables parsed from vars file and build context (base VM, target VM, args)
display_build_variables() {
    local vars_file="${1:-}"
    local base_vm_name="${2:-}"
    local target_vm_name="${3:-}"
    log_info "=========================================="
    log_info "Variables parsed from file and build context"
    log_info "=========================================="
    if [[ -n "$vars_file" ]] && [[ -f "$vars_file" ]]; then
        log_info "Contents of variables file ($vars_file):"
        while IFS= read -r line; do
            # Redact password values when displaying
            if [[ "$line" =~ password.*= ]]; then
                log_info "  ${line%%=*}=***REDACTED***"
            else
                log_info "  $line"
            fi
        done < "$vars_file"
    fi
    log_info "Base VM name: $base_vm_name"
    log_info "Target VM name: $target_vm_name"
    log_info "All arguments passed to build.sh: $*"
    log_info "=========================================="
}

# Clone base VM to windows-target-vm-{timestamp}. Used in ISO mode (base = Packer VM) and existing_base mode (base = user's VM).
# ISO mode: base_vm_name = Packer-created VM (e.g. windows-base-vm-{timestamp}); we power it off, then clone to target. Unchanged.
# existing_base mode: base_vm_name = user's VM name; we resolve to inventory path and clone so -vm is unambiguous.
# Caller must have GOVC_* set. Outputs the new VM name to stdout for capture.
# Optional second arg: vars_file for vcenter_datastore, vcenter_datacenter. Third arg: power_off_before_clone (default true; use false for template).
clone_current_vm_to_target() {
    local base_vm_name="${1:?}"
    local vars_file="${2:-}"
    local power_off_before_clone="${3:-true}"   # true for ISO base VM and existing_base VM; false only when cloning from template elsewhere
    local timestamp=$(date -u +"%Y%m%d%H%M%S" 2>/dev/null || date +"%Y%m%d%H%M%S" 2>/dev/null || echo "")
    local target_vm_name="windows-target-vm-${timestamp}"

    log_info "Base VM (to clone): $base_vm_name"
    log_info "Target VM (clone for stembuild): $target_vm_name"

    # For govc vm.clone -vm: use inventory path when base_vm_name is a name (not already a path). Path is unambiguous; fall back to name if resolution fails.
    local vm_to_clone="$base_vm_name"
    local datacenter=""
    if [[ -n "$vars_file" ]] && [[ -f "$vars_file" ]]; then
        datacenter=$(get_var "$vars_file" "vcenter_datacenter")
        datacenter=$(printf '%s' "${datacenter:-}" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    fi
    if [[ "$base_vm_name" != /* ]]; then
        local resolved_path
        resolved_path=$(find_vm_inventory_path "$base_vm_name" "$datacenter") || true
        if [[ -n "$resolved_path" ]]; then
            vm_to_clone="$resolved_path"
            log_info "Using inventory path for clone: $vm_to_clone"
        fi
    fi

    if ! vm_exists "$base_vm_name"; then
        log_error "VM/template not found: $base_vm_name"
        return 1
    fi

    # Power off base VM before cloning (skip when cloning from template)
    if [[ "$power_off_before_clone" == "true" ]]; then
        log_info "Powering off base VM before clone..."
        if ! vm_power_off "$base_vm_name" 120 1; then
            log_error "Base VM did not power off within timeout"
            return 1
        fi
        log_success "Base VM powered off"
    fi

    # Specify datastore when multiple exist
    local clone_opts=(-vm "$vm_to_clone")
    if [[ -n "$vars_file" ]] && [[ -f "$vars_file" ]]; then
        local datastore
        datastore=$(get_var "$vars_file" "vcenter_datastore")
        if [[ -n "$datastore" ]]; then
            clone_opts+=(-ds "$datastore")
            log_info "Using datastore for clone: $datastore"
        fi
    fi
    clone_opts+=("$target_vm_name")

    log_info "Cloning to $target_vm_name (govc vm.clone -vm ...)..."
    if ! govc vm.clone "${clone_opts[@]}" 1>&2; then
        log_error "Clone failed"
        return 1
    fi
    log_success "Clone created: $target_vm_name"

    local vm_wait=0
    while [[ $vm_wait -lt 300 ]]; do
        if vm_exists "$target_vm_name"; then
            break
        fi
        sleep 5
        vm_wait=$((vm_wait + 5))
    done
    if ! vm_exists "$target_vm_name"; then
        log_error "Target VM not found after clone: $target_vm_name"
        return 1
    fi

    # Output new VM name to stdout so caller can capture
    printf '%s' "$target_vm_name"
    return 0
}

# Setup proxy environment variables
setup_proxy_environment() {
    local vars_file="${1:-}"
    
    # If vars file exists, try to extract proxy settings
    if [[ -n "$vars_file" ]] && [[ -f "$vars_file" ]]; then
        # Extract proxy settings from variables file using grep/sed
        # This is a simple approach - for complex parsing, consider using hcl2json
        local http_proxy=$(grep -E "^http_proxy\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        local https_proxy=$(grep -E "^https_proxy\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        local no_proxy=$(grep -E "^no_proxy\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        local proxy_user=$(grep -E "^proxy_username\s*=" "$vars_file" | sed 's/.*=\s*"\(.*\)".*/\1/' | sed 's/.*=\s*\(.*\)/\1/' | head -1)
        local proxy_pass=$(grep -E "^proxy_password\s*=" "$vars_file" | sed 's/.*=\s*"\(.*\)".*/\1/' | sed 's/.*=\s*\(.*\)/\1/' | head -1)
        
        # Build proxy URLs with authentication if credentials provided
        if [[ -n "$http_proxy" ]] && [[ "$http_proxy" != '""' ]] && [[ -n "$http_proxy" ]]; then
            # Remove quotes if present
            http_proxy=$(echo "$http_proxy" | sed 's/^"//;s/"$//')
            
            # Add default port if not specified
            if [[ "$http_proxy" =~ ^http://[^:]+$ ]]; then
                log_warn "HTTP proxy missing port, assuming default port 80"
                http_proxy="${http_proxy}:80"
            fi
            
            if [[ -n "$proxy_user" ]] && [[ -n "$proxy_pass" ]] && [[ "$proxy_user" != '""' ]] && [[ "$proxy_pass" != '""' ]]; then
                # Remove quotes from credentials
                proxy_user=$(echo "$proxy_user" | sed 's/^"//;s/"$//')
                proxy_pass=$(echo "$proxy_pass" | sed 's/^"//;s/"$//')
                # Insert credentials into proxy URL
                http_proxy=$(echo "$http_proxy" | sed "s|://|://${proxy_user}:${proxy_pass}@|")
            fi
            export HTTP_PROXY="$http_proxy"
            export http_proxy="$http_proxy"
            log_info "HTTP proxy configured: $http_proxy"
        fi
        
        if [[ -n "$https_proxy" ]] && [[ "$https_proxy" != '""' ]] && [[ -n "$https_proxy" ]]; then
            # Remove quotes if present
            https_proxy=$(echo "$https_proxy" | sed 's/^"//;s/"$//')
            
            # Add default port if not specified
            if [[ "$https_proxy" =~ ^http://[^:]+$ ]]; then
                log_warn "HTTPS proxy missing port, assuming default port 80"
                https_proxy="${https_proxy}:80"
            fi
            
            if [[ -n "$proxy_user" ]] && [[ -n "$proxy_pass" ]] && [[ "$proxy_user" != '""' ]] && [[ "$proxy_pass" != '""' ]]; then
                # Remove quotes from credentials
                proxy_user=$(echo "$proxy_user" | sed 's/^"//;s/"$//')
                proxy_pass=$(echo "$proxy_pass" | sed 's/^"//;s/"$//')
                https_proxy=$(echo "$https_proxy" | sed "s|://|://${proxy_user}:${proxy_pass}@|")
            fi
            export HTTPS_PROXY="$https_proxy"
            export https_proxy="$https_proxy"
            log_info "HTTPS proxy configured: $https_proxy"
        fi
        
        if [[ -n "$no_proxy" ]] && [[ "$no_proxy" != '""' ]]; then
            export NO_PROXY="$no_proxy"
            export no_proxy="$no_proxy"
            log_info "NO_PROXY configured: $no_proxy"
        fi
    fi
    
    # Also check environment variables (can override vars file)
    if [[ -n "${HTTP_PROXY:-}" ]]; then
        log_info "Using HTTP_PROXY from environment: ${HTTP_PROXY%%:*}"
    fi
    if [[ -n "${HTTPS_PROXY:-}" ]]; then
        log_info "Using HTTPS_PROXY from environment: ${HTTPS_PROXY%%:*}"
    fi
    if [[ -n "${NO_PROXY:-}" ]]; then
        log_info "Using NO_PROXY from environment: $NO_PROXY"
    fi
}

# Initialize Packer
init_packer() {
    log_info "Initializing Packer plugins..."
    
    # Ensure we're in the script directory
    cd "$SCRIPT_DIR" || {
        log_error "Failed to change to script directory: $SCRIPT_DIR"
        exit 1
    }

    if packer init windows-vm.pkr.hcl; then
        log_success "Packer plugins initialized"
    else
        log_error "Failed to initialize Packer plugins"
        exit 1
    fi
}

# Upload local ISO to datastore
# Parameters:
#   $1: vars_file - Variables file path
#   $2: iso_local - Local ISO file path (original, for logging)
#   $3: resolved_iso_path - Resolved absolute path to local ISO file
#   $4: destination_path - Destination datastore path (e.g., [datastore]/ISOs/file.iso)
#   $5: force_upload - Force re-upload even if exists (default: false)
upload_iso_to_datastore() {
    local vars_file="${1:-}"
    local iso_local="${2:-}"
    local resolved_iso_path="${3:-}"
    local destination_path="${4:-}"  # Destination path on datastore
    local force_upload="${5:-false}"  # Force re-upload even if exists
    
    # All logging functions now go to stderr, so only the path will be returned to stdout
    log_info "=========================================="
    log_info "ISO Upload Process Starting"
    log_info "=========================================="
    log_info "Local ISO file: $resolved_iso_path"
    
    # Note: Proxy environment variables should be set by calling function
    # govc uses HTTP_PROXY, HTTPS_PROXY, NO_PROXY environment variables
    
    # Extract vCenter and datastore info from variables file
    if [[ -n "$vars_file" ]] && [[ -f "$vars_file" ]]; then
        log_info "Extracting vCenter configuration from variables file..."
        
        local vcenter_server=$(grep -E "^vcenter_server\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        local vcenter_user=$(grep -E "^vcenter_username\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        local vcenter_pass=$(grep -E "^vcenter_password\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        local vcenter_insecure=$(grep -E "^vcenter_insecure_connection\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        local datastore=$(grep -E "^vcenter_datastore\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        local datacenter=$(grep -E "^vcenter_datacenter\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        # Remove quotes
        vcenter_server=$(echo "$vcenter_server" | sed 's/^"//;s/"$//')
        vcenter_user=$(echo "$vcenter_user" | sed 's/^"//;s/"$//')
        vcenter_pass=$(echo "$vcenter_pass" | sed 's/^"//;s/"$//')
        datastore=$(echo "$datastore" | sed 's/^"//;s/"$//')
        
        log_info "vCenter Server: $vcenter_server"
        log_info "vCenter User: $vcenter_user"
        log_info "Datastore: $datastore"
        log_info "Insecure Connection: $vcenter_insecure"
        
        # Get ISO filename and size
        local iso_filename=$(basename "$resolved_iso_path")
        local iso_size=$(du -h "$resolved_iso_path" | cut -f1)
        
        # Determine destination path
        local datastore_path=""
        local final_destination_path=""
        if [[ -n "$destination_path" ]] && [[ "$destination_path" =~ ^\[.+\]/ ]]; then
            # Destination path provided in format [datastore]/path/to/file.iso
            local dest_datastore=$(echo "$destination_path" | sed 's/^\[\([^]]*\)\].*/\1/')
            datastore_path=$(echo "$destination_path" | sed 's/^\[[^]]*\]\///')
            final_destination_path="$destination_path"
            log_info "Using provided destination path: $final_destination_path"
            
            # Verify datastore matches
            if [[ "$dest_datastore" != "$datastore" ]]; then
                log_warn "Destination datastore ($dest_datastore) differs from configured datastore ($datastore)"
                log_warn "Using destination datastore: $dest_datastore"
                datastore="$dest_datastore"
            fi
        else
            # Default: upload to ISOs folder with same filename
            datastore_path="ISOs/$iso_filename"
            final_destination_path="[$datastore]/$datastore_path"
            log_info "Using default destination path: $final_destination_path"
        fi
        
        log_info "ISO Filename: $iso_filename"
        log_info "ISO Size: $iso_size"
        log_info "Target Datastore Path: $final_destination_path"
        
        # Check if govc is available and setup
        if ! command -v govc >/dev/null 2>&1; then
            log_error "govc is required to upload ISO to datastore"
            exit 1
        fi
        
        export GOVC_URL="$vcenter_server" GOVC_USERNAME="$vcenter_user" GOVC_PASSWORD="$vcenter_pass"
        [[ "$vcenter_insecure" == "true" ]] && export GOVC_INSECURE=true
        
        # Verify connection and datastore
        govc about >/dev/null 2>&1 || { log_error "Failed to connect to vCenter"; return 1; }
        govc datastore.info "$datastore" >/dev/null 2>&1 || { log_error "Datastore not found: $datastore"; return 1; }
        
        # Check if ISO already exists on datastore (unless force upload is requested)
        if [[ "$force_upload" != "true" ]]; then
            log_info "=========================================="
            log_info "Checking if ISO already exists on datastore"
            log_info "=========================================="
            log_info "Checking for: $final_destination_path"
            
            # Get local file size for comparison
            local local_iso_size_bytes=$(stat -f%z "$resolved_iso_path" 2>/dev/null || stat -c%s "$resolved_iso_path" 2>/dev/null || echo "0")
            
            # Check if file exists on datastore
            if govc datastore.ls -ds "$datastore" "$datastore_path" >/dev/null 2>&1; then
            log_success "ISO file found on datastore: $final_destination_path"
            
            # Try to get file size from datastore for comparison
            log_info "Verifying ISO file details..."
            local datastore_file_info=$(govc datastore.ls -ds "$datastore" -l "$datastore_path" 2>/dev/null || echo "")
            local datastore_iso_size_bytes=""
            
            if [[ -n "$datastore_file_info" ]]; then
                log_debug "Datastore file info: $datastore_file_info"
                
                # Try to extract file size in bytes (govc output format may vary)
                # Look for size patterns like "5.3GB", "5652088832", etc.
                if [[ "$datastore_file_info" =~ ([0-9]+)[[:space:]]+[0-9]+\.[0-9]+[KMGT]?B ]]; then
                    datastore_iso_size_bytes="${BASH_REMATCH[1]}"
                elif [[ "$datastore_file_info" =~ ([0-9]+) ]]; then
                    # Try to get the first large number (likely file size)
                    datastore_iso_size_bytes=$(echo "$datastore_file_info" | grep -oE '[0-9]{8,}' | head -1 || echo "")
                fi
                
                # Also try to get human-readable size
                local datastore_iso_size_human=$(echo "$datastore_file_info" | grep -oE '[0-9]+\.[0-9]+[KMGT]?B' | head -1 || echo "")
                if [[ -n "$datastore_iso_size_human" ]]; then
                    log_info "Datastore ISO size: $datastore_iso_size_human"
                fi
            fi
            
            # Compare file sizes if we have both
            if [[ -n "$datastore_iso_size_bytes" ]] && [[ "$local_iso_size_bytes" != "0" ]] && [[ "$datastore_iso_size_bytes" != "" ]]; then
                log_info "Local ISO size: $iso_size ($local_iso_size_bytes bytes)"
                log_info "Datastore ISO size: $datastore_iso_size_bytes bytes"
                
                # Allow small difference (1MB) for rounding/formatting differences
                local size_diff=$((local_iso_size_bytes - datastore_iso_size_bytes))
                local size_diff_abs=${size_diff#-}  # Absolute value
                
                if [[ $size_diff_abs -lt 1048576 ]]; then  # Less than 1MB difference
                    log_success "File sizes match (difference < 1MB) - using existing ISO"
                    log_info "Skipping upload to avoid duplicate"
                    # Return datastore path in correct format: [datastore]/path/to/file.iso
                    # Ensure path is properly formatted
                    if [[ -z "$datastore" ]] || [[ -z "$datastore_path" ]]; then
                        log_error "Cannot construct datastore path - datastore or path is empty"
                        log_error "Datastore: '$datastore'"
                        log_error "Datastore path: '$datastore_path'"
                        exit 1
                    fi
                    local return_path="[$datastore]/$datastore_path"
                    # Trim any whitespace/newlines and ensure no trailing characters
                    return_path=$(printf '%s' "$return_path" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    log_info "Returning datastore path: '$return_path'"
                    # Output ONLY the path to stdout (for capture), all logs go to stderr
                    printf '%s' "$return_path" >&1
                    return 0
                else
                    log_warn "File sizes differ significantly (${size_diff_abs} bytes)"
                    log_warn "This may be a different ISO file"
                    log_warn "Options:"
                    log_warn "  1. Delete existing ISO on datastore and re-upload"
                    log_warn "  2. Rename local ISO file"
                    log_warn "  3. Use different filename on datastore"
                    log_error "Upload aborted to prevent overwriting different file"
            return 1
                fi
            else
                # If we can't compare sizes, just check if file exists
                log_info "Local ISO size: $iso_size ($local_iso_size_bytes bytes)"
                log_warn "Could not retrieve datastore file size for comparison"
                log_info "Using existing ISO on datastore (assuming it's the same file)"
                log_info "Skipping upload to avoid duplicate"
                # Return datastore path in correct format: [datastore]/path/to/file.iso
                # Ensure path is properly formatted
                if [[ -z "$datastore" ]] || [[ -z "$datastore_path" ]]; then
                    log_error "Cannot construct datastore path - datastore or path is empty"
                    log_error "Datastore: '$datastore'"
                    log_error "Datastore path: '$datastore_path'"
                    exit 1
                fi
                local return_path="$final_destination_path"
                # Trim any whitespace/newlines and ensure no trailing characters
                return_path=$(printf '%s' "$return_path" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                log_info "Returning datastore path: '$return_path'"
                # Output ONLY the path to stdout (all logs go to stderr)
                printf '%s' "$return_path"
                return 0
            fi
        else
            log_info "ISO not found on datastore"
            log_info "Proceeding with upload..."
        fi
        else
            # Force upload requested - skip existence check
            log_info "=========================================="
            log_info "Force Re-upload Requested"
            log_info "=========================================="
            log_info "Skipping existence check - will re-upload ISO"
            log_info "Target: $final_destination_path"
            
            # Delete existing ISO if it exists (to ensure clean upload)
            if govc datastore.ls -ds "$datastore" "$datastore_path" >/dev/null 2>&1; then
                log_info "Deleting existing ISO on datastore..."
                if govc datastore.rm -ds "$datastore" "$datastore_path" 2>/dev/null; then
                    log_info "✓ Existing ISO deleted"
                else
                    log_warn "Could not delete existing ISO (may be in use, will overwrite)"
                fi
            fi
        fi
        
        log_info "=========================================="
        
        # Upload ISO
        log_info "=========================================="
        log_info "Starting ISO Upload"
        log_info "=========================================="
        log_info "Source: $resolved_iso_path"
        log_info "Destination: [$datastore]/$datastore_path"
        log_info "Size: $iso_size"
        log_warn "This may take a while for large ISO files..."
        log_info "Upload progress will be shown below:"
        log_info "------------------------------------------"
        
        # Upload with progress indication
        local upload_start=$(date +%s)
        if govc datastore.upload -ds "$datastore" "$resolved_iso_path" "$datastore_path" 2>&1 | while IFS= read -r line; do
            # Show upload progress if available (redirect to stderr)
            if [[ "$line" =~ progress|upload|percent ]]; then
                log_info "Upload: $line" >&2
            elif [[ -n "$line" ]]; then
                log_debug "govc: $line" >&2
            fi
        done; then
            local upload_end=$(date +%s)
            local upload_duration=$((upload_end - upload_start))
            local upload_minutes=$((upload_duration / 60))
            local upload_seconds=$((upload_duration % 60))
            
            log_info "------------------------------------------"
            log_success "ISO uploaded successfully!"
            log_info "Upload completed in ${upload_minutes}m ${upload_seconds}s"
            log_info "Location: [$datastore]/$datastore_path"
            
            # Verify upload
            log_info "Verifying uploaded ISO..."
            if govc datastore.ls -ds "$datastore" "$datastore_path" >/dev/null 2>&1; then
                log_success "ISO verification successful"
                # Return datastore path in correct format: [datastore]/path/to/file.iso
                # Use the final_destination_path which was already formatted
                local return_path="$final_destination_path"
                # Trim any whitespace/newlines
                return_path=$(echo -n "$return_path" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                log_info "Returning datastore path: '$return_path'"
                # Output ONLY the path to stdout (all logs go to stderr)
                printf '%s' "$return_path"
                return 0
            else
                log_error "ISO upload verification failed"
                log_error "File may not have been uploaded correctly"
                exit 1
            fi
        else
            log_error "------------------------------------------"
            log_error "ISO upload failed!"
            log_error "Please check:"
            log_error "  - Network connectivity to vCenter"
            log_error "  - Datastore permissions"
            log_error "  - Available space on datastore"
            exit 1
        fi
    else
        log_error "Variables file not found, cannot upload ISO"
        exit 1
    fi
}

# ISO injection method removed - using floppy_content method instead

# Validate ISO configuration
# Skips ISO validation when template_path or existing_base_vm_name is set (one of template_path, existing_base_vm_name, or ISO must be provided).
validate_iso_config() {
    local vars_file="${1:-}"
    local overwrite_flag="${2:-false}"
    
    if [[ -n "$vars_file" ]] && [[ -f "$vars_file" ]]; then
        local template_path_val existing_base_val
        template_path_val=$(trim_var "$(get_var "$vars_file" "template_path")")
        existing_base_val=$(trim_var "$(get_var "$vars_file" "existing_base_vm_name")")
        if [[ -n "$template_path_val" ]] || [[ -n "$existing_base_val" ]]; then
            log_info "Template path or existing base VM provided; skipping ISO validation"
            return 0
        fi
    fi

    log_info "Validating ISO configuration..."
    
    if [[ -n "$vars_file" ]] && [[ -f "$vars_file" ]]; then
        # Check if at least one ISO path is configured (use get_var + trim_var for consistency with build mode)
        local iso_local iso_path
        iso_local=$(trim_var "$(get_var "$vars_file" "iso_path_local")")
        iso_path=$(trim_var "$(get_var "$vars_file" "iso_path")")
        
        # Variable to store uploaded ISO path (if upload happens)
        local datastore_iso_path=""
        
        # Determine the logic based on what's provided:
        # - iso_path_local = source file (local)
        # - iso_path = destination path (datastore path where ISO should be)
        # 
        # Cases:
        # 1. Only iso_path provided: Validate it exists, use it directly (skip upload)
        # 2. Both provided: Upload iso_path_local to iso_path destination
        # 3. Only iso_path_local: Error (need destination)
        
        # Not set = empty after trim; only fail when both ISO paths are not set (mode already chose ISO, so one should be set)
        if [[ -z "$iso_local" ]] && [[ -z "$iso_path" ]]; then
            log_error "Build source missing: provide exactly one of the following:"
            log_error "  - template_path (clone from existing template)"
            log_error "  - existing_base_vm_name (clone from existing VM, then stembuild)"
            log_error "  - iso_path (with optional iso_path_local) for ISO install"
            exit 1
        fi
        
        # Case 1: Only iso_path_local provided (without iso_path) - ERROR
        if [[ -n "$iso_local" ]] && [[ -z "$iso_path" ]]; then
            log_error "iso_path_local provided but iso_path (destination) is missing!"
            log_error "When uploading a local ISO, you must specify iso_path as the destination"
            log_error "Example: iso_path = \"[datastore1]/ISOs/windows-server-2019.iso\""
            exit 1
        fi
        
        # Case 2: Both iso_path_local and iso_path provided - Upload iso_path_local to iso_path
        if [[ -n "$iso_local" ]] && [[ -n "$iso_path" ]]; then
            # Resolve relative paths relative to script directory (windows-automation folder)
            local resolved_iso_path="$iso_local"
            if [[ "$iso_local" != /* ]]; then
                # Relative path - resolve relative to script directory
                # Remove any "./" prefix first
                local clean_path="${iso_local#./}"
                # Build absolute path
                resolved_iso_path="$SCRIPT_DIR/$clean_path"
                # Remove duplicate slashes
                resolved_iso_path=$(echo "$resolved_iso_path" | sed 's|//|/|g')
            fi
            
            log_debug "Checking ISO path: $resolved_iso_path (original: $iso_local)"
            
            if [[ ! -f "$resolved_iso_path" ]]; then
                log_error "Local ISO file not found: $resolved_iso_path"
                log_error "Original path: $iso_local"
                log_error "Current directory: $(pwd)"
                log_error "Script directory: $SCRIPT_DIR"
                log_error "Please verify the path is correct"
                log_error "Expected location: $SCRIPT_DIR/windows-server-2019.iso"
                exit 1
            fi
            
            # Verify this is a Windows Server ISO, not VMware Tools ISO
            local iso_filename=$(basename "$resolved_iso_path")
            if echo "$iso_filename" | grep -qiE "(tools|vmware)"; then
                log_error "ERROR: ISO file appears to be VMware Tools ISO, not Windows Server ISO!"
                log_error "File: $iso_filename"
                log_error "This ISO should be Windows Server 2019/2022 ISO for booting the VM"
                log_error "VMware Tools ISO should NOT be used for booting"
                exit 1
            elif ! echo "$iso_filename" | grep -qiE "(windows|server|2019|2022)"; then
                log_warn "WARNING: ISO filename doesn't contain 'windows' or 'server' keywords"
                log_warn "File: $iso_filename"
                log_warn "Please verify this is a Windows Server ISO"
            else
                log_info "✅ Verified: ISO is Windows Server ISO"
            fi
            
            log_info "Local ISO file found: $resolved_iso_path"
            
            # Check if destination (iso_path) already exists on datastore
            log_info "Checking if destination ISO already exists on datastore..."
            local iso_datastore=$(echo "$iso_path" | sed 's/^\[\([^]]*\)\].*/\1/')
            local iso_file=$(echo "$iso_path" | sed 's/^\[[^]]*\]\///')
            
            # Set govc environment for checking
            local vcenter_server=$(grep -E "^vcenter_server\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
            local vcenter_user=$(grep -E "^vcenter_username\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
            local vcenter_pass=$(grep -E "^vcenter_password\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
            local vcenter_insecure=$(grep -E "^vcenter_insecure_connection\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
            
            vcenter_server=$(echo "$vcenter_server" | sed 's/^"//;s/"$//')
            vcenter_user=$(echo "$vcenter_user" | sed 's/^"//;s/"$//')
            vcenter_pass=$(echo "$vcenter_pass" | sed 's/^"//;s/"$//')
            
            export GOVC_URL="$vcenter_server"
            export GOVC_USERNAME="$vcenter_user"
            export GOVC_PASSWORD="$vcenter_pass"
            if [[ "$vcenter_insecure" == "true" ]]; then
                export GOVC_INSECURE=true
            fi
            
            local iso_exists=false
            if govc datastore.ls -ds "$iso_datastore" "$iso_file" >/dev/null 2>&1; then
                iso_exists=true
                log_info "ISO already exists on datastore: $iso_path"
                
                if [[ "$overwrite_flag" == "true" ]]; then
                    log_info "Overwrite flag set - will upload and replace existing ISO"
                else
                    log_success "Skipping upload - ISO already exists at destination"
                    log_info "Use --overwrite flag to force upload and replace existing ISO"
                    # Set the path without uploading
                    datastore_iso_path="$iso_path"
                fi
            else
                log_info "ISO not found on datastore - will upload"
            fi
            
            # Upload ISO to datastore destination (iso_path) if needed
            if [[ "$iso_exists" != "true" ]] || [[ "$overwrite_flag" == "true" ]]; then
                log_info "Uploading iso_path_local to iso_path destination..."
                log_info "  Source (local): $resolved_iso_path"
                log_info "  Destination: $iso_path"
                # Use overwrite_flag for force upload
                datastore_iso_path=$(upload_iso_to_datastore "$vars_file" "$iso_local" "$resolved_iso_path" "$iso_path" "$overwrite_flag")
                local upload_exit_code=$?
            
                if [[ $upload_exit_code -ne 0 ]]; then
                    log_error "ISO upload function failed with exit code: $upload_exit_code"
                    exit 1
                fi
            else
                # Upload skipped - use existing ISO path
                datastore_iso_path="$iso_path"
                log_info "Using existing ISO at: $datastore_iso_path"
            fi
            
            # Trim any whitespace/newlines from the path using printf to avoid echo issues
            datastore_iso_path=$(printf '%s' "$datastore_iso_path" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Debug: Show what we got
            log_info "Received datastore path from upload function:"
            log_info "  Raw path: '$datastore_iso_path'"
            log_info "  Path length: ${#datastore_iso_path} characters"
            
            # Check if path is empty
            if [[ -z "$datastore_iso_path" ]]; then
                log_error "Upload function returned empty path!"
                log_error "This indicates the upload function did not return a valid path"
                log_error "Please check the upload_iso_to_datastore function"
                exit 1
            fi
            
            # Verify the path format is correct (should be [datastore]/path/to/file.iso)
            if [[ ! "$datastore_iso_path" =~ ^\[.+\]/ ]]; then
                log_error "Invalid datastore path format!"
                log_error "Received path: '$datastore_iso_path'"
                log_error "Expected format: [datastore-name]/path/to/file.iso"
                log_error "Path length: ${#datastore_iso_path} characters"
                if command -v xxd >/dev/null 2>&1; then
                    log_error "Path hex dump: $(printf '%s' "$datastore_iso_path" | xxd -p | head -1)"
                fi
                log_error "First character: '$(printf '%s' "$datastore_iso_path" | cut -c1)'"
                log_error "Path breakdown:"
                log_error "  Starts with '[': $([[ "$datastore_iso_path" =~ ^\[ ]] && echo "yes" || echo "no")"
                log_error "  Contains ']/': $([[ "$datastore_iso_path" =~ \]/ ]] && echo "yes" || echo "no")"
                exit 1
            fi
            
            log_info "ISO path format validated: $datastore_iso_path"
            
            # Verify file exists on datastore (only if we uploaded, not if we skipped)
            if [[ "$iso_exists" != "true" ]] || [[ "$overwrite_flag" == "true" ]]; then
                log_info "Verifying uploaded ISO exists on datastore..."
                local datastore_name=$(echo "$datastore_iso_path" | sed 's/^\[\([^]]*\)\].*/\1/')
                local iso_file_path=$(echo "$datastore_iso_path" | sed 's/^\[[^]]*\]\///')
                
                # Note: Proxy environment variables should be set by calling function
                # govc uses HTTP_PROXY, HTTPS_PROXY, NO_PROXY environment variables
                
                # Set govc environment for verification
                local vcenter_server=$(grep -E "^vcenter_server\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
                local vcenter_user=$(grep -E "^vcenter_username\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
                local vcenter_pass=$(grep -E "^vcenter_password\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
                local vcenter_insecure=$(grep -E "^vcenter_insecure_connection\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
                
                vcenter_server=$(echo "$vcenter_server" | sed 's/^"//;s/"$//')
                vcenter_user=$(echo "$vcenter_user" | sed 's/^"//;s/"$//')
                vcenter_pass=$(echo "$vcenter_pass" | sed 's/^"//;s/"$//')
                
                export GOVC_URL="$vcenter_server"
                export GOVC_USERNAME="$vcenter_user"
                export GOVC_PASSWORD="$vcenter_pass"
                if [[ "$vcenter_insecure" == "true" ]]; then
                    export GOVC_INSECURE=true
                fi
                
                log_info "Verifying ISO exists at:"
                log_info "  Datastore: $datastore_name"
                log_info "  File path: $iso_file_path"
                log_info "  Full path: $datastore_iso_path"
                
                if govc datastore.ls -ds "$datastore_name" "$iso_file_path" >/dev/null 2>&1; then
                    log_success "ISO verified on datastore: $datastore_iso_path"
                else
                    log_error "ISO verification failed - file not found at: $datastore_iso_path"
                    log_error "Datastore: $datastore_name"
                    log_error "File path: $iso_file_path"
                    exit 1
                fi
                
                # ISO uploaded successfully to destination
                log_info "ISO uploaded successfully to destination: $datastore_iso_path"
            fi
        fi
        
        # Case 3: Only iso_path provided - Validate it exists and use it directly
        if [[ -n "$iso_path" ]] && [[ "$iso_path" != '""' ]]; then
            # Verify this is a Windows Server ISO, not VMware Tools ISO
            if echo "$iso_path" | grep -qiE "(tools|vmware)"; then
                log_error "ERROR: iso_path appears to point to VMware Tools ISO, not Windows Server ISO!"
                log_error "Path: $iso_path"
                log_error "This should point to Windows Server 2019/2022 ISO for booting the VM"
                log_error "VMware Tools ISO path: [] /vmimages/tools-isoimages/windows.iso"
                log_error "Windows Server ISO should be like: [datastore]/ISOs/windows-server-2019.iso"
                exit 1
            elif ! echo "$iso_path" | grep -qiE "(windows|server|2019|2022)"; then
                log_warn "WARNING: ISO path doesn't contain 'windows' or 'server' keywords"
                log_warn "Path: $iso_path"
                log_warn "Please verify this is a Windows Server ISO"
            else
                log_info "✅ Verified: ISO path is Windows Server ISO"
            fi
            
            log_info "Using iso_path from variables file: $iso_path"
            
            # Verify the path format is correct (should be [datastore]/path/to/file.iso)
            if [[ ! "$iso_path" =~ ^\[.+\]/ ]]; then
                log_error "Invalid datastore path format in iso_path!"
                log_error "Path: '$iso_path'"
                log_error "Expected format: [datastore-name]/path/to/file.iso"
                exit 1
            fi
            
            # Validate ISO exists on datastore (if not uploaded in this run)
            if [[ -z "${datastore_iso_path:-}" ]] || [[ "$datastore_iso_path" != "$iso_path" ]]; then
                log_info "Validating ISO exists on datastore: $iso_path"
                local iso_datastore=$(echo "$iso_path" | sed 's/^\[\([^]]*\)\].*/\1/')
                local iso_file=$(echo "$iso_path" | sed 's/^\[[^]]*\]\///')
                
                # Set govc environment for validation
                local vcenter_server=$(grep -E "^vcenter_server\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
                local vcenter_user=$(grep -E "^vcenter_username\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
                local vcenter_pass=$(grep -E "^vcenter_password\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
                local vcenter_insecure=$(grep -E "^vcenter_insecure_connection\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
                
                vcenter_server=$(echo "$vcenter_server" | sed 's/^"//;s/"$//')
                vcenter_user=$(echo "$vcenter_user" | sed 's/^"//;s/"$//')
                vcenter_pass=$(echo "$vcenter_pass" | sed 's/^"//;s/"$//')
                
                export GOVC_URL="$vcenter_server"
                export GOVC_USERNAME="$vcenter_user"
                export GOVC_PASSWORD="$vcenter_pass"
                if [[ "$vcenter_insecure" == "true" ]]; then
                    export GOVC_INSECURE=true
                fi
                
                if govc datastore.ls -ds "$iso_datastore" "$iso_file" >/dev/null 2>&1; then
                    log_success "ISO verified on datastore: $iso_path"
                else
                    log_error "ISO file not found on datastore: $iso_path"
                    log_error "Datastore: $iso_datastore"
                    log_error "File path: $iso_file"
                    log_error "Please verify the ISO exists at this location"
                    exit 1
                fi
            fi
            
            # Set environment variable for Packer
            # Packer automatically reads PKR_VAR_* environment variables and sets var.*
            export PKR_VAR_iso_path="$iso_path"
            log_info "Environment variable set: PKR_VAR_iso_path='$iso_path'"
            log_info "Packer will use this ISO path to mount the CD-ROM drive"
        fi
    else
        log_warn "Variables file not found, skipping ISO validation"
        log_warn "ISO path must be configured in variables file or via command line"
    fi
}

# Validate Packer configuration
validate_packer() {
    local vars_file="${1:-}"
    
    log_info "Validating Packer configuration..."
    
    # Ensure we're in the script directory
    cd "$SCRIPT_DIR" || {
        log_error "Failed to change to script directory: $SCRIPT_DIR"
        exit 1
    }
    
    # guest_os_type is set once in main (set_packer_guest_os_type); pass explicitly so var-file cannot override
    local validate_cmd="packer validate"
    
    if [[ -n "$vars_file" ]]; then
        validate_cmd="$validate_cmd -var-file=$vars_file"
        log_info "Using variables file: $vars_file"
    fi
    if [[ -n "${PKR_VAR_guest_os_type:-}" ]]; then
        validate_cmd="$validate_cmd -var=guest_os_type=${PKR_VAR_guest_os_type}"
    fi
    
    validate_cmd="$validate_cmd windows-vm.pkr.hcl"
    
    log_debug "Running: $validate_cmd"
    
    if eval "$validate_cmd"; then
        log_success "Packer configuration is valid"
    else
        log_error "Packer configuration validation failed"
        exit 1
    fi
}

# Process Autounattend.xml template with sed (simpler than Packer's templatefile)
process_autounattend_template() {
    local vars_file="${1:-}"
    
    if [[ -z "$vars_file" ]] || [[ ! -f "$vars_file" ]]; then
        log_error "Variables file not found: $vars_file"
        return 1
    fi
    
    log_info "Processing Autounattend.xml template..."
    
    # Extract username, password, and network settings from variables file
    local username=$(grep -E "^windows_username\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local password=$(grep -E "^windows_password\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local static_ip=$(grep -E "^static_ip\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local subnet_mask=$(grep -E "^subnet_mask\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local gateway=$(grep -E "^gateway\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    # Extract DNS servers - handle both "dns_servers" and "dnsserver" variable names
    # Handle both array format: [value] or ["value"] and string format: "value"
    # Extract the IP address(es) directly, not as array string
    local dns_servers_line=$(grep -E "^(dns_servers|dnsserver)\s*=" "$vars_file" | sed 's/#.*$//' | head -1)
    local dns_servers=""
    if [[ -n "$dns_servers_line" ]]; then
        # Check if it's an array format [value] or string format "value"
        if echo "$dns_servers_line" | grep -q '\['; then
            # Array format: [192.168.111.155] or ["192.168.111.155"]
            if command -v perl >/dev/null 2>&1; then
                dns_servers=$(echo "$dns_servers_line" | perl -pe 's/.*?=\s*\[([^\]]+)\].*/$1/' | sed 's/"//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            else
                # Fallback: use sed with more specific pattern
                dns_servers=$(echo "$dns_servers_line" | sed -n 's/.*=\s*\[\([^]]*\)\].*/\1/p' | sed 's/"//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            fi
        else
            # String format: "192.168.111.155" (single IP, not array)
            dns_servers=$(echo "$dns_servers_line" | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        fi
    fi
    local dns_server1=$(echo "$dns_servers" | cut -d',' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # Extract DNS server 2 only if there's actually a comma (multiple servers)
    local dns_server2=""
    if echo "$dns_servers" | grep -q ','; then
        dns_server2=$(echo "$dns_servers" | cut -d',' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
    # Also ensure dns_server2 is different from dns_server1 (avoid duplicates)
    if [[ "$dns_server2" == "$dns_server1" ]]; then
        dns_server2=""
    fi
    
    # Convert subnet mask to prefix length (CIDR notation)
    # Example: 255.255.255.0 -> 24
    local subnet_prefix=""
    if [[ -n "$subnet_mask" ]]; then
        # Use Python or Perl for reliable calculation
        if command -v python3 >/dev/null 2>&1; then
            subnet_prefix=$(python3 -c "
import sys
mask = '$subnet_mask'.split('.')
prefix = 0
for octet in mask:
    octet_int = int(octet)
    # Count bits set to 1
    while octet_int > 0:
        prefix += octet_int & 1
        octet_int >>= 1
print(prefix)
")
        elif command -v perl >/dev/null 2>&1; then
            subnet_prefix=$(perl -e "
my \$mask = '$subnet_mask';
my @octets = split(/\./, \$mask);
my \$prefix = 0;
foreach my \$octet (@octets) {
    my \$o = int(\$octet);
    while (\$o > 0) {
        \$prefix++ if (\$o & 1);
        \$o >>= 1;
    }
}
print \$prefix;
")
        else
            # Fallback: common subnet masks
            case "$subnet_mask" in
                255.255.255.0) subnet_prefix="24" ;;
                255.255.0.0) subnet_prefix="16" ;;
                255.0.0.0) subnet_prefix="8" ;;
                255.255.255.128) subnet_prefix="25" ;;
                255.255.255.192) subnet_prefix="26" ;;
                255.255.255.224) subnet_prefix="27" ;;
                255.255.255.240) subnet_prefix="28" ;;
                255.255.255.248) subnet_prefix="29" ;;
                255.255.255.252) subnet_prefix="30" ;;
                *)
                    log_warn "Unknown subnet mask: $subnet_mask, defaulting to /24"
                    subnet_prefix="24"
                    ;;
            esac
        fi
    fi
    
    if [[ -z "$username" ]]; then
        log_error "windows_username not found in $vars_file"
        return 1
    fi
    
    if [[ -z "$password" ]]; then
        log_error "windows_password not found in $vars_file"
        return 1
    fi
    
    if [[ -z "$static_ip" ]] || [[ -z "$subnet_mask" ]] || [[ -z "$gateway" ]] || [[ -z "$dns_server1" ]]; then
        log_error "Network configuration incomplete in $vars_file"
        log_error "Required: static_ip, subnet_mask, gateway, dns_servers"
        return 1
    fi
    
    log_info "Extracted username: $username"
    log_info "Extracted password: ${password:0:3}*** (hidden)"
    log_info "Extracted static_ip: $static_ip"
    log_info "Extracted subnet_mask: $subnet_mask"
    log_info "Calculated subnet_prefix: $subnet_prefix"
    log_info "Extracted gateway: $gateway"
    log_info "Extracted dns_server1: $dns_server1"
    [[ -n "$dns_server2" ]] && log_info "Extracted dns_server2: $dns_server2"
    
    # Source template file - use path relative to script directory
    local template_file="$SCRIPT_DIR/http/Autounattend.xml"
    local processed_file="$SCRIPT_DIR/http/Autounattend.processed.xml"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "Template file not found: $template_file"
        log_error "Expected path relative to build script: $SCRIPT_DIR/http/Autounattend.xml"
        return 1
    fi
    
    # Get Windows version for image name
    local windows_version=$(grep -E "^windows_version\s*=" "$vars_file" 2>/dev/null | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//' || echo "2019")
    if [[ -z "$windows_version" ]]; then
        windows_version="2019"
    fi
    
    # Determine Windows image name based on version
    local windows_image_name=""
    case "$windows_version" in
        2019)
            windows_image_name="Windows Server 2019 SERVERSTANDARDCORE"
            ;;
        2022)
            windows_image_name="Windows Server 2022 SERVERSTANDARDCORE"
            ;;
        2025)
            windows_image_name="Windows Server 2025 SERVERSTANDARDCORE"
            ;;
        *)
            log_error "Unsupported Windows version: $windows_version (supported: 2019, 2022, 2025)"
            return 1
            ;;
    esac
    log_info "Using Windows image name: $windows_image_name"
    
    # Escape special characters for sed
    local escaped_username=$(echo "$username" | sed 's/[[\.*^$()+?{|]/\\&/g') || {
        log_error "Failed to escape username for sed"
        return 1
    }
    local escaped_password=$(echo "$password" | sed 's/[[\.*^$()+?{|]/\\&/g') || {
        log_error "Failed to escape password for sed"
        return 1
    }
    local escaped_static_ip=$(echo "$static_ip" | sed 's/[[\.*^$()+?{|]/\\&/g') || {
        log_error "Failed to escape static_ip for sed"
        return 1
    }
    local escaped_subnet_mask=$(echo "$subnet_mask" | sed 's/[[\.*^$()+?{|]/\\&/g') || {
        log_error "Failed to escape subnet_mask for sed"
        return 1
    }
    local escaped_subnet_prefix=$(echo "$subnet_prefix" | sed 's/[[\.*^$()+?{|]/\\&/g') || {
        log_error "Failed to escape subnet_prefix for sed"
        return 1
    }
    local escaped_gateway=$(echo "$gateway" | sed 's/[[\.*^$()+?{|]/\\&/g') || {
        log_error "Failed to escape gateway for sed"
        return 1
    }
    local escaped_dns_servers=$(echo "$dns_servers" | sed 's/[[\.*^$()+?{|]/\\&/g') || {
        log_error "Failed to escape dns_servers for sed"
        return 1
    }
    local escaped_dns_server1=$(echo "$dns_server1" | sed 's/[[\.*^$()+?{|]/\\&/g') || {
        log_error "Failed to escape dns_server1 for sed"
        return 1
    }
    local escaped_dns_server2=$(echo "$dns_server2" | sed 's/[[\.*^$()+?{|]/\\&/g' 2>/dev/null || echo "")
    local escaped_windows_image_name=$(echo "$windows_image_name" | sed 's/[[\.*^$()+?{|]/\\&/g') || {
        log_error "Failed to escape windows_image_name for sed"
        return 1
    }
    
    # Generate XML for optional DNSServer2
    # If DNSServer2 is provided, include it; otherwise leave placeholder empty (will be removed)
    local dns_server2_xml=""
    if [[ -n "$dns_server2" ]] && [[ "$dns_server2" != "" ]]; then
        dns_server2_xml="                        <IpAddress wcm:action=\"add\" wcm:keyValue=\"2\">$dns_server2</IpAddress>"
    fi
    
    # Replace template variables with actual values
    # Use '|' as sed delimiter to avoid conflicts with XML characters like '/' and '<'
    # First, replace all variables except DNSServer2_XML
    # All sed commands must succeed - if any fails, the script will exit due to set -euo pipefail
    local temp_file=$(mktemp)
    if ! sed -e "s|{{\.Username}}|$escaped_username|g" \
        -e "s|{{\.Password}}|$escaped_password|g" \
        -e "s|{{\.StaticIP}}|$escaped_static_ip|g" \
        -e "s|{{\.SubnetMask}}|$escaped_subnet_mask|g" \
        -e "s|{{\.SubnetPrefix}}|$escaped_subnet_prefix|g" \
        -e "s|{{\.Gateway}}|$escaped_gateway|g" \
        -e "s|{{\.DNSServer1}}|$escaped_dns_server1|g" \
        -e "s|{{\.WindowsImageName}}|$escaped_windows_image_name|g" \
        "$template_file" > "$temp_file"; then
        log_error "sed command failed while processing Autounattend.xml template"
        rm -f "$temp_file"
        return 1
    fi
    
    # FirstLogonCommandsSConfigBlock: for 2022/2025 inject "Disable SConfig Auto-launch" so SConfig does not block automation; for 2019 omit
    local temp_file2=$(mktemp)
    local sconfig_block_file=$(mktemp)
    if [[ "$windows_version" == "2022" ]] || [[ "$windows_version" == "2025" ]]; then
        cat >> "$sconfig_block_file" << 'SCONFIG_BLOCK_EOF'
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd /c reg add "HKCU\Software\Microsoft\ServerConfig" /v "AutoLaunch" /t REG_DWORD /d 0 /f</CommandLine>
                    <Description>Disable SConfig Auto-launch</Description>
                    <Order>1</Order>
                </SynchronousCommand>
SCONFIG_BLOCK_EOF
        awk -v blockfile="$sconfig_block_file" '
            /\{\{\.FirstLogonCommandsSConfigBlock\}\}/ {
                while ((getline line < blockfile) > 0) print line
                close(blockfile)
                next
            }
            { print }
        ' "$temp_file" > "$temp_file2"
        log_info "Added FirstLogonCommands entry to disable SConfig auto-launch (Windows $windows_version)"
    else
        awk '/\{\{\.FirstLogonCommandsSConfigBlock\}\}/ { next }; { print }' "$temp_file" > "$temp_file2"
    fi
    rm -f "$sconfig_block_file"
    if [[ ! -f "$temp_file2" ]] || [[ ! -s "$temp_file2" ]]; then
        log_error "Failed to process FirstLogonCommandsSConfigBlock"
        rm -f "$temp_file" "$temp_file2"
        return 1
    fi
    rm -f "$temp_file"
    local temp_file="$temp_file2"
    
    # ProductKeyXML: for 2022/2025 inject Generic KMS key (GVLK) in windowsPE UserData so product key is not missing; for 2019 omit
    local product_key_file=$(mktemp)
    local temp_file3=$(mktemp)
    if [[ "$windows_version" == "2022" ]]; then
        # Windows Server 2022 Standard GVLK (Microsoft KMS client activation keys)
        cat >> "$product_key_file" << 'PRODUCTKEY_EOF'
                <ProductKey>
                    <Key>VDYBN-27WPP-V4HQT-9VMD4-VMK7H</Key>
                    <WillShowUI>Never</WillShowUI>
                </ProductKey>
PRODUCTKEY_EOF
        awk -v pkfile="$product_key_file" '
            /\{\{\.ProductKeyXML\}\}/ { while ((getline line < pkfile) > 0) print line; close(pkfile); next }
            { print }
        ' "$temp_file" > "$temp_file3"
        log_info "Added Generic KMS key (GVLK) for Windows Server 2022 Standard in windowsPE"
    elif [[ "$windows_version" == "2025" ]]; then
        # Windows Server 2025 Standard GVLK (Microsoft KMS client activation keys)
        cat >> "$product_key_file" << 'PRODUCTKEY_EOF'
                <ProductKey>
                    <Key>TVRH6-WHNXV-R9WG3-9XRFY-MY832</Key>
                    <WillShowUI>Never</WillShowUI>
                </ProductKey>
PRODUCTKEY_EOF
        awk -v pkfile="$product_key_file" '
            /\{\{\.ProductKeyXML\}\}/ { while ((getline line < pkfile) > 0) print line; close(pkfile); next }
            { print }
        ' "$temp_file" > "$temp_file3"
        log_info "Added Generic KMS key (GVLK) for Windows Server 2025 Standard in windowsPE"
    else
        # 2019: remove placeholder line (2019 does not require product key in answer file for this scenario)
        awk '/\{\{\.ProductKeyXML\}\}/ { next }; { print }' "$temp_file" > "$temp_file3"
    fi
    rm -f "$product_key_file"
    if [[ ! -f "$temp_file3" ]] || [[ ! -s "$temp_file3" ]]; then
        log_error "Failed to process ProductKeyXML"
        rm -f "$temp_file" "$temp_file3"
        return 1
    fi
    rm -f "$temp_file"
    temp_file="$temp_file3"
    
    # Handle DNSServer2_XML separately - if empty, remove the placeholder line entirely
    if [[ -n "$dns_server2_xml" ]]; then
        # DNSServer2 is provided - replace placeholder with XML
        # Use awk to handle the replacement more safely (avoids sed escaping issues)
        if ! awk -v replacement="$dns_server2_xml" '{gsub(/\{\{\.DNSServer2_XML\}\}/, replacement); print}' "$temp_file" > "$processed_file"; then
            log_error "awk command failed while processing DNSServer2_XML"
            rm -f "$temp_file"
            return 1
        fi
    else
        # DNSServer2 is not provided - remove the placeholder line entirely
        if ! sed "/{{\.DNSServer2_XML}}/d" "$temp_file" > "$processed_file"; then
            log_error "sed command failed while removing DNSServer2_XML placeholder"
            rm -f "$temp_file"
            return 1
        fi
    fi
    
    # Clean up temp file
    rm -f "$temp_file"
    
    if [[ ! -f "$processed_file" ]]; then
        log_error "Failed to create processed Autounattend.xml"
        return 1
    fi
    
    # Check if processed file is empty
    if [[ ! -s "$processed_file" ]]; then
        log_error "Processed Autounattend.xml is empty!"
        log_error "Template processing may have failed"
        return 1
    fi
    
    # # Validate XML syntax
    # if ! xmllint --noout "$processed_file" 2>/dev/null; then
    #     log_error "Processed Autounattend.xml has XML syntax errors!"
    #     log_error "Please check the template processing"
    #     return 1
    # fi
    
    # Verify replacements - all grep commands must succeed
    if ! grep -q "{{\.Password}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.Username}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.StaticIP}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.SubnetMask}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.SubnetPrefix}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.Gateway}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.DNSServer1}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.DNSServer2_XML}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.WindowsImageName}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.FirstLogonCommandsSConfigBlock}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.ProductKeyXML}}" "$processed_file" 2>/dev/null; then
        log_info "All template variables replaced successfully"
    else
        log_error "Template variables were not replaced!"
        log_error "Check that Autounattend.xml uses correct template variables"
        # Show which variables are still present
        if grep -q "{{\.Password}}" "$processed_file" 2>/dev/null; then log_error "  - {{.Password}} still present"; fi
        if grep -q "{{\.Username}}" "$processed_file" 2>/dev/null; then log_error "  - {{.Username}} still present"; fi
        if grep -q "{{\.StaticIP}}" "$processed_file" 2>/dev/null; then log_error "  - {{.StaticIP}} still present"; fi
        if grep -q "{{\.SubnetMask}}" "$processed_file" 2>/dev/null; then log_error "  - {{.SubnetMask}} still present"; fi
        if grep -q "{{\.SubnetPrefix}}" "$processed_file" 2>/dev/null; then log_error "  - {{.SubnetPrefix}} still present"; fi
        if grep -q "{{\.Gateway}}" "$processed_file" 2>/dev/null; then log_error "  - {{.Gateway}} still present"; fi
        if grep -q "{{\.DNSServer1}}" "$processed_file" 2>/dev/null; then log_error "  - {{.DNSServer1}} still present"; fi
        if grep -q "{{\.DNSServer2_XML}}" "$processed_file" 2>/dev/null; then log_error "  - {{.DNSServer2_XML}} still present"; fi
        if grep -q "{{\.WindowsImageName}}" "$processed_file" 2>/dev/null; then log_error "  - {{.WindowsImageName}} still present"; fi
        if grep -q "{{\.FirstLogonCommandsSConfigBlock}}" "$processed_file" 2>/dev/null; then log_error "  - {{.FirstLogonCommandsSConfigBlock}} still present"; fi
        if grep -q "{{\.ProductKeyXML}}" "$processed_file" 2>/dev/null; then log_error "  - {{.ProductKeyXML}} still present"; fi
        return 1
    fi
    
    log_success "Processed Autounattend.xml created: $processed_file"
    log_info "Template variables replaced successfully"
    log_info "XML syntax validated"
    
    return 0
}

# Build the VM
build_vm() {
    local vars_file="${1:-}"
    local log_level="${LOG_LEVEL:-INFO}"
    
    log_info "Starting Packer build process..."
    log_info "Log level: $log_level"
    
    # Display variables and VM names before proceeding
    local vm_name_base=$(grep -E "^vm_name\s*=" "$vars_file" 2>/dev/null | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local timestamp="${PKR_VAR_build_timestamp:-$(date -u +"%Y%m%d%H%M%S" 2>/dev/null || date +"%Y%m%d%H%M%S" 2>/dev/null || echo "")}"
    local vm_name_final="${vm_name_base:-vm}-${timestamp}"
    display_build_variables "$vars_file" "${vm_name_base:-}" "$vm_name_final" "(Packer will create VM: $vm_name_final)"
    
    # Create logs directory
    mkdir -p logs
    
    # NOTE: Background floppy connection monitor removed
    # This approach doesn't work because Packer blocks execution during boot.
    # Packer powers on VM immediately and waits for boot to complete.
    # There's no timing window for a background script to intervene.
    # 
    # Solution: Ensure floppy_content is properly configured in windows-vm.pkr.hcl
    # See FLOPPY-TIMING-ANALYSIS.md for details.
    
    # Note: Proxy environment variables should be set by calling function
    # Packer vsphere-iso builder uses HTTP_PROXY, HTTPS_PROXY, NO_PROXY environment variables
    # Verify proxy is set (for debugging)
    if [[ -n "${HTTPS_PROXY:-}" ]]; then
        log_info "Proxy will be used for Packer connections"
        log_debug "HTTPS_PROXY=${HTTPS_PROXY}"
    else
        log_info "No proxy configured - direct connection to vCenter"
    fi
    
    # Ensure we're in the script directory for Packer commands
    cd "$SCRIPT_DIR" || {
        log_error "Failed to change to script directory: $SCRIPT_DIR"
        exit 1
    }
    
    # Build command
    # Note: PKR_VAR_iso_path may be set by validate_iso_config if iso_path_local was used
    # Packer automatically reads PKR_VAR_* environment variables
    local build_cmd="packer build"
    
    # Validate ISO path is set before building
    if [[ -z "${PKR_VAR_iso_path:-}" ]]; then
        log_error "ISO path is not set! PKR_VAR_iso_path environment variable is empty"
        log_error "This will cause the VM to start without an ISO mounted"
        log_error "Please ensure either iso_path or iso_path_local is set in your variables file"
        exit 1
    fi
    
    # Log environment variables that will be used
    log_info "Using ISO path from environment: ${PKR_VAR_iso_path}"
    log_info "Packer will mount this ISO to the VM: ${PKR_VAR_iso_path}"
    
    # Verify ISO path format before passing to Packer
    # Format must be: [datastore-name]/path/to/file.iso
    if [[ ! "${PKR_VAR_iso_path}" =~ ^\[.+\]/ ]]; then
        log_error "Invalid ISO path format: ${PKR_VAR_iso_path}"
        log_error "Expected format: [datastore-name]/path/to/file.iso"
        log_error "Example: [datastore1]/ISOs/windows-server-2019.iso"
        exit 1
    fi
    
    # Extract datastore name and file path for verification (build_vm is only called for ISO mode)
    local iso_datastore iso_file
    iso_datastore=$(echo "${PKR_VAR_iso_path}" | sed 's/^\[\([^]]*\)\].*/\1/')
    iso_file=$(echo "${PKR_VAR_iso_path}" | sed 's/^\[[^]]*\]\///')
    log_info "ISO Datastore: $iso_datastore"
    log_info "ISO File Path: $iso_file"
    log_info "Full ISO Path: ${PKR_VAR_iso_path}"
    
    # Verify ISO is accessible on datastore before Packer tries to use it
    if [[ -n "$vars_file" ]] && [[ -f "$vars_file" ]]; then
        log_info "Verifying ISO is accessible on datastore before build..."
        local vcenter_server=$(grep -E "^vcenter_server\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        local vcenter_user=$(grep -E "^vcenter_username\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        local vcenter_pass=$(grep -E "^vcenter_password\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        local vcenter_insecure=$(grep -E "^vcenter_insecure_connection\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        
        vcenter_server=$(echo "$vcenter_server" | sed 's/^"//;s/"$//')
        vcenter_user=$(echo "$vcenter_user" | sed 's/^"//;s/"$//')
        vcenter_pass=$(echo "$vcenter_pass" | sed 's/^"//;s/"$//')
        
        export GOVC_URL="$vcenter_server"
        export GOVC_USERNAME="$vcenter_user"
        export GOVC_PASSWORD="$vcenter_pass"
        if [[ "$vcenter_insecure" == "true" ]]; then
            export GOVC_INSECURE=true
        fi
        
        if govc datastore.ls -ds "$iso_datastore" "$iso_file" >/dev/null 2>&1; then
            log_success "ISO verified accessible on datastore: ${PKR_VAR_iso_path}"
        else
            log_error "ISO file not accessible on datastore: ${PKR_VAR_iso_path}"
            log_error "Datastore: $iso_datastore"
            log_error "File path: $iso_file"
            log_error "Please verify the ISO exists and the path is correct"
            log_error "Listing datastore contents:"
            govc datastore.ls -ds "$iso_datastore" 2>&1 | head -20 | while IFS= read -r line; do
                log_error "  $line"
            done
            exit 1
        fi
    fi
    
    # guest_os_type set once in main; pass explicitly so var-file cannot override (same as iso_path)
    if [[ -n "${PKR_VAR_guest_os_type:-}" ]]; then
        build_cmd="$build_cmd -var=guest_os_type=${PKR_VAR_guest_os_type}"
    fi
    
    # Add variables file if provided
    if [[ -n "$vars_file" ]]; then
        build_cmd="$build_cmd -var-file=$vars_file"
    fi
    
    # Explicitly pass ISO path via -var flag to ensure it takes precedence
    # This ensures the ISO is mounted even if iso_path is empty in the variables file
    # Note: The path with brackets needs to be properly escaped/quoted
    # Using printf %q to properly escape the path for shell
    local escaped_iso_path=$(printf '%q' "${PKR_VAR_iso_path}")
    build_cmd="$build_cmd -var=iso_path=${escaped_iso_path}"
    log_info "ISO path explicitly set via -var flag: ${PKR_VAR_iso_path}"
    
    # Add log level
    build_cmd="$build_cmd -var=log_level=$log_level"
    
    # Enable debug mode if log level is DEBUG
    if [[ "$log_level" == "DEBUG" ]]; then
        build_cmd="$build_cmd -debug"
    fi
    
    # Add the Packer file
    build_cmd="$build_cmd windows-vm.pkr.hcl"
    
    log_info "Build command: $build_cmd"
    log_info "Build logs will be saved to: logs/"
    log_info "This process may take 30-60 minutes depending on Windows updates..."
    log_info ""
    
    # Run the build
    local build_start=$(date +%s)
    local log_file="logs/packer-build-$(date +%Y%m%d-%H%M%S).log"
    
    # Extract VM name and timestamp BEFORE running Packer (needed for post-build provisioning)
    local vm_name_base=$(grep -E "^vm_name\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local timestamp="${PKR_VAR_build_timestamp:-}"
    
    # Generate timestamp if not set (should be set by main function before Packer runs)
    if [[ -z "$timestamp" ]]; then
        timestamp=$(date -u +"%Y%m%d%H%M%S" 2>/dev/null || date +"%Y%m%d%H%M%S" 2>/dev/null || echo "")
        log_warn "Timestamp not found in PKR_VAR_build_timestamp - generated new one: $timestamp"
    fi
    
    local vm_name_final="${vm_name_base:-windows-base-vm}-${timestamp}"
    log_info "VM name for post-build provisioning: $vm_name_final"
    
    # Run Packer build in background to prevent shutdown wait from blocking
    # Packer will wait for shutdown (5 minutes), but we'll proceed with provisioning in parallel
    log_info "Starting Packer build in background..."
    log_info "Packer will wait for shutdown (will timeout), but build.sh proceeds immediately"
    
    # Start Packer in background and capture PID
    eval "$build_cmd" > "$log_file" 2>&1 &
    local packer_pid=$!
    log_info "Packer started with PID: $packer_pid"
    log_info "Packer logs: $log_file"
    
    # Detect build mode before setting up cleanup (use get_var for portable parsing)
    local template_path iso_path iso_path_local
    template_path=$(trim_var "$(get_var "$vars_file" "template_path")")
    iso_path=$(trim_var "$(get_var "$vars_file" "iso_path")")
    iso_path_local=$(trim_var "$(get_var "$vars_file" "iso_path_local")")
    
    local build_mode="iso"
    if [[ -n "$template_path" ]] && [[ -z "$iso_path" ]] && [[ -z "$iso_path_local" ]] && [[ -z "${PKR_VAR_iso_path:-}" ]] && [[ -z "${PKR_VAR_iso_path_local:-}" ]]; then
        build_mode="template"
    fi
    
    # Set up cleanup variables and trap for error handling (log path for printing on exit 1 in CI)
    CLEANUP_PACKER_PID="$packer_pid"
    if [[ "$log_file" == /* ]]; then
        CLEANUP_PACKER_LOG_FILE="$log_file"
    else
        CLEANUP_PACKER_LOG_FILE="${SCRIPT_DIR}/${log_file}"
    fi
    CLEANUP_VM_NAME="$vm_name_final"
    CLEANUP_BUILD_MODE="$build_mode"
    CLEANUP_VARS_FILE="$vars_file"
    CLEANUP_ALREADY_RAN=false
    CLEANUP_ENABLED=true
    
    # Single EXIT trap: run cleanup only on non-zero exit when cleanup is enabled
    trap 'exit_code=$?; if [[ $exit_code -ne 0 ]] && [[ "$CLEANUP_ENABLED" == "true" ]]; then cleanup_on_failure $exit_code; fi' EXIT
    
    # Wait for Packer to create VM in vSphere (VM creation is fast, but boot sequence takes minutes)
    # We're only waiting for VM object creation, not for boot sequence to complete
    # Boot sequence runs in parallel - we'll start provisioning after installation completes
    log_info "Waiting 60 seconds for Packer to create VM in vSphere..."
    log_info "Note: VM creation is fast (~10-30s), but boot sequence takes several minutes"
    log_info "We're only waiting for VM object creation, not for installation to complete"
    sleep 60
    
    # Verify VM exists before starting post-build provisioning
    log_info "Verifying VM exists before starting post-build provisioning..."
    local vcenter_server=$(grep -E "^vcenter_server\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local vcenter_user=$(grep -E "^vcenter_username\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local vcenter_pass=$(grep -E "^vcenter_password\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local vcenter_insecure=$(grep -E "^vcenter_insecure_connection\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
    
    export GOVC_URL="$vcenter_server"
    export GOVC_USERNAME="$vcenter_user"
    export GOVC_PASSWORD="$vcenter_pass"
    if [[ "$vcenter_insecure" == "true" ]]; then
        export GOVC_INSECURE=true
    fi
    
    # Wait for VM to be created (with timeout)
    local vm_wait_timeout=300  # 5 minutes
    local vm_elapsed=0
    while [[ $vm_elapsed -lt $vm_wait_timeout ]]; do
        if vm_exists "$vm_name_final"; then
            log_success "VM found: $vm_name_final"
            break
        fi
        sleep 5
        vm_elapsed=$((vm_elapsed + 5))
        if [[ $((vm_elapsed % 30)) -eq 0 ]]; then
            log_info "Waiting for VM to be created... (${vm_elapsed}s elapsed)"
        fi
    done
    
    if [[ $vm_elapsed -ge $vm_wait_timeout ]]; then
        log_error "=========================================="
        log_error "VM CREATION/CLONE FAILED"
        log_error "=========================================="
        log_error "VM not found after ${vm_wait_timeout}s: $vm_name_final"
        log_error "Build mode: $build_mode"
        if [[ "$build_mode" == "template" ]]; then
            log_error "Template path: $template_path"
            log_error "Packer may have failed to clone from template"
        else
            log_error "ISO path: ${PKR_VAR_iso_path:-}"
            log_error "Packer may have failed to create VM from ISO"
        fi
        log_error "Check Packer logs: $log_file"
        log_error "Packer log (last 500 lines):"
        tail -500 "$log_file" 2>/dev/null | while IFS= read -r line; do
            log_error "  $line"
        done || log_error "  (Could not read log file)"
        log_error "=========================================="
        # Cleanup trap will also print Packer log so CI captures it
        exit 1
    fi
    
    # Wait for Windows installation and first boot to complete before starting post-build provisioning
    # Packer boot commands include <wait120> for installation start and <wait60> for first boot
    # But actual installation takes 7-30 minutes, so we need to wait longer
    # We'll wait for the boot sequence to complete before attempting password change
    log_info "Waiting for Windows installation and first boot to complete..."
    log_info "Boot sequence includes: installation (~7-30 min) + first boot (~1-2 min)"
    log_info "Waiting 7 minutes to ensure installation and first boot are complete..."
    log_info "This ensures the password change screen is ready before we attempt to handle it"
    sleep 420  # 7 minutes - allows Windows installation and first boot to complete
    
    # Detect build mode (iso or template)
    # If template_path is provided and no ISO is configured, use template mode
    # Otherwise, use ISO mode (template_path can still be used to create template after stemcell)
    local build_mode="iso"
    local template_path iso_path iso_path_local template_name_early
    template_path=$(trim_var "$(get_var "$vars_file" "template_path")")
    iso_path=$(trim_var "$(get_var "$vars_file" "iso_path")")
    iso_path_local=$(trim_var "$(get_var "$vars_file" "iso_path_local")")
    template_name_early=$(trim_var "$(get_var "$vars_file" "template_name")")
    
    if [[ -n "$template_path" ]] && [[ -z "$iso_path" ]] && [[ -z "$iso_path_local" ]] && [[ -z "${PKR_VAR_iso_path:-}" ]] && [[ -z "${PKR_VAR_iso_path_local:-}" ]]; then
        build_mode="template"
        log_info "Template mode detected: will clone from $template_path"
    else
        build_mode="iso"
        log_info "ISO mode detected: will build from ISO"
        if [[ -n "$template_path" ]] || [[ -n "$template_name_early" ]]; then
            log_info "Template will be created after stemcell packaging"
        fi
    fi
    
    # Start post-build provisioning
    log_info "Starting post-build provisioning..."
    post_build_provisioning "$vars_file" "$vm_name_final" "$build_mode" "$log_level"
    local provisioning_exit_code=$?
    
    # Disable cleanup on success (trap still runs but will no-op when exit_code is 0)
    CLEANUP_ENABLED=false
    
    # After template is created, stop Packer process (it's waiting for shutdown timeout)
    # Packer has a 2-hour shutdown timeout, but we've completed all provisioning
    # No need to wait for Packer to timeout - kill it now
    if [[ $provisioning_exit_code -eq 0 ]]; then
        local build_end=$(date +%s)
        local build_duration=$((build_end - build_start))
        local build_minutes=$((build_duration / 60))
        log_success "Build and provisioning completed successfully in ${build_minutes} minutes"
        log_info "Template created - stopping Packer process (it's waiting for shutdown timeout)..."
        
        # Kill Packer process if still running
        if kill -0 "$packer_pid" 2>/dev/null; then
            log_info "Stopping Packer process (PID: $packer_pid)"
            kill "$packer_pid" 2>/dev/null || true
            # Wait a moment for process to terminate
            sleep 2
            # Force kill if still running
            if kill -0 "$packer_pid" 2>/dev/null; then
                log_warn "Packer process still running - forcing kill"
                kill -9 "$packer_pid" 2>/dev/null || true
            fi
            log_success "Packer process stopped"
        else
            log_info "Packer process already finished"
        fi
    else
        log_error "=========================================="
        log_error "POST-BUILD PROVISIONING FAILED"
        log_error "=========================================="
        log_error "Exit code: $provisioning_exit_code"
        log_error "Build mode: $build_mode"
        log_error "VM name: $vm_name_final"
        log_error "Recent log files (tail below so Concourse shows content):"
        local log_count=0
        while IFS= read -r logfile; do
            [[ $log_count -ge 2 ]] && break
            log_error "--- Last 200 lines of $logfile ---"
            tail -200 "$logfile" 2>/dev/null | while IFS= read -r line; do log_error "  $line"; done
            log_count=$((log_count + 1))
        done < <(ls -t "$SCRIPT_DIR/logs/"*.log 2>/dev/null | head -2)
        if [[ $log_count -eq 0 ]]; then
            log_error "  (No log files found in $SCRIPT_DIR/logs/)"
        fi
        log_error "=========================================="
        # Cleanup will be handled by trap
        exit 1
    fi
}

# Post-build provisioning: configure VM and create stemcell.
# build_mode: iso | template | existing_base (same three as main).
#
# Flow summary:
# - Template and existing_base: target VM (windows-target-vm-{timestamp}) is ready at entry. Steps run on that VM:
#   Step 2 network config -> Step 3 Windows updates -> Step 3.6 guest wait -> stembuild construct -> package.
# - ISO: base VM at entry -> Step 1 password change + VMware Tools -> Step 2 network + Step 3 updates on base ->
#   Step 3.5 clone to target (windows-target-vm-{timestamp}) -> Step 3.6 guest wait on target -> stembuild -> package.
post_build_provisioning() {
    local vars_file="${1:-}"
    local vm_name="${2:-}"
    local build_mode="${3:-iso}"  # "iso" | "template" | "existing_base"
    local log_level="${4:-INFO}"
    
    if [[ -z "$vars_file" ]] || [[ -z "$vm_name" ]]; then
        log_error "post_build_provisioning: Missing required parameters"
        return 1
    fi

    # true when target VM is already the one we work on (template/existing_base). false for ISO (we start on base VM, clone to target later).
    local target_ready_mode=false
    [[ "$build_mode" == "template" ]] || [[ "$build_mode" == "existing_base" ]] && target_ready_mode=true
    
    log_info "Starting post-build provisioning for VM: $vm_name (mode: $build_mode)"
    
    # Extract variables from vars file (get_var always returns 0; empty if key missing)
    local vcenter_server vcenter_user vcenter_pass vcenter_insecure
    local windows_username windows_password patch_version template_path template_name vcenter_folder keep_base_vm datacenter
    vcenter_server=$(get_var "$vars_file" "vcenter_server")
    vcenter_user=$(get_var "$vars_file" "vcenter_username")
    vcenter_pass=$(get_var "$vars_file" "vcenter_password")
    vcenter_insecure=$(get_var "$vars_file" "vcenter_insecure_connection")
    windows_username=$(get_var "$vars_file" "windows_username")
    windows_password=$(get_var "$vars_file" "windows_password")
    patch_version=$(get_var "$vars_file" "patch_version")
    template_path=$(get_var "$vars_file" "template_path")
    template_name=$(get_var "$vars_file" "template_name")
    vcenter_folder=$(get_var "$vars_file" "vcenter_folder")
    keep_base_vm=$(get_var "$vars_file" "keep_base_vm")
    datacenter=$(trim_var "$(get_var "$vars_file" "vcenter_datacenter")")
    
    # Track base VM name for ISO mode cleanup (only clone in ISO mode; base_vm_name is the VM before clone)
    local base_vm_name="$vm_name"
    
    # Default username to Administrator if not specified
    if [[ -z "$windows_username" ]]; then
        windows_username="Administrator"
    fi
    
    # Early validation: required for govc and guest operations
    if [[ -z "${vcenter_server:-}" ]] || [[ -z "${vcenter_user:-}" ]] || [[ -z "${vcenter_pass:-}" ]]; then
        log_error "post_build_provisioning: vcenter_server, vcenter_username, and vcenter_password must be set in vars file"
        return 1
    fi
    if [[ -z "${windows_password:-}" ]]; then
        log_error "post_build_provisioning: windows_password must be set in vars file (required for guest operations)"
        return 1
    fi
    if [[ -z "${patch_version:-}" ]]; then
        log_error "post_build_provisioning: patch_version must be set in vars file (required for stembuild)"
        return 1
    fi

    # Set govc environment
    export GOVC_URL="$vcenter_server"
    export GOVC_USERNAME="$vcenter_user"
    export GOVC_PASSWORD="$vcenter_pass"
    if [[ "$vcenter_insecure" == "true" ]]; then
        export GOVC_INSECURE=true
    fi
    
    # Verify VM exists
    if ! vm_exists "$vm_name"; then
        log_error "VM not found: $vm_name"
        return 1
    fi
    
    local scripts_dir="$SCRIPT_DIR/scripts"
    # Scripts used in this workflow (all under scripts/):
    #   handle-password-change-keystrokes.sh, mount-vmware-tools.sh, install-vmware-tools-keystrokes.sh,
    #   run-powershell-via-govc.sh, configure-network-manual.ps1, run-windows-updates-loop.sh,
    #   install-windows-updates.ps1, check-updates-after-reboot.ps1, run-stembuild-construct.sh.
    # package-stemcell.sh lives in SCRIPT_DIR (windows-automation/).

    # Poll govc vm.info guest block until guestOperationsReady and toolsRunningStatus indicate Tools are ready.
    # Uses solid state from vSphere (no guest.start); use after Tools install. Reboot/wait logic unchanged.
    wait_for_vm_tools_ready() {
        local vname="${1:?}" timeout_sec="${2:-600}" interval=30 elapsed=0
        while [[ $elapsed -lt $timeout_sec ]]; do
            local ready status
            ready=$(govc vm.info -json "$vname" 2>/dev/null | jq -r '.virtualMachines[0].guest.guestOperationsReady // false')
            status=$(govc vm.info -json "$vname" 2>/dev/null | jq -r '.virtualMachines[0].guest.toolsRunningStatus // empty')
            if [[ "$ready" == "true" ]] && [[ "$status" == "guestToolsRunning" ]]; then
                return 0
            fi
            sleep $interval
            elapsed=$((elapsed + interval))
        done
        return 1
    }

    # Helper: wait for guest operations on a VM (VM must be powered on). Returns 0 when ready, 1 on timeout.
    # Used by template/existing_base before Step 2 and by ISO after clone (Step 3.6).
    wait_for_vm_guest_ready() {
        local vname="${1:?}"
        local timeout_sec="${2:-600}"
        local wait_interval=30
        local wait_elapsed=0
        local govc_guest_opts=(-vm "$vname" -l "${windows_username}:${windows_password}")
        local ps_exe="C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
        local tmp_stderr
        tmp_stderr=$(mktemp 2>/dev/null) || tmp_stderr=""
        while [[ $wait_elapsed -lt $timeout_sec ]]; do
            local pid
            if [[ -n "$tmp_stderr" ]]; then
                pid=$(govc guest.start "${govc_guest_opts[@]}" "$ps_exe" "-ExecutionPolicy" "Bypass" "-NoProfile" "-NoLogo" "-NonInteractive" "-Command" "exit 0" 2>"$tmp_stderr") || true
            else
                pid=$(govc guest.start "${govc_guest_opts[@]}" "$ps_exe" "-ExecutionPolicy" "Bypass" "-NoProfile" "-NoLogo" "-NonInteractive" "-Command" "exit 0" 2>/dev/null) || true
            fi
            if [[ -n "$pid" ]]; then
                local raw code
                raw=$(govc guest.ps "${govc_guest_opts[@]}" -p "$pid" -X -x 2>/dev/null) || true
                code=$(echo "$raw" | awk -v p="$pid" 'NR>1 && $2+0==p+0 {print $5; exit}')
                [[ -z "$code" ]] && code=$(echo "$raw" | grep -o '"exitCode":[0-9]*' | head -1 | sed 's/"exitCode"://')
                if [[ "${code:-1}" == "0" ]]; then
                    rm -f "$tmp_stderr" 2>/dev/null || true
                    return 0
                fi
            fi
            sleep $wait_interval
            wait_elapsed=$((wait_elapsed + wait_interval))
        done
        rm -f "$tmp_stderr" 2>/dev/null || true
        return 1
    }

    # Step 1: Password change and VMware Tools (ISO mode only). Skip for template/existing_base (target already has Tools).
    if [[ "$build_mode" == "iso" ]]; then
        local wait_before_password_change="${WAIT_BEFORE_PASSWORD_CHANGE_SECONDS:-60}"
        log_info "Step 1: Waiting ${wait_before_password_change}s before password change..."
        sleep "$wait_before_password_change"

        log_info "Step 1: Handling password change (ISO mode)..."
        local password_change_log="$SCRIPT_DIR/logs/password-change-$(date +%Y%m%d-%H%M%S).log"
        mkdir -p "$(dirname "$password_change_log")"
        run_script "$scripts_dir/handle-password-change-keystrokes.sh" "$vm_name" "$windows_password" "$password_change_log" || {
            log_error "Password change failed."
            if [[ -f "$password_change_log" ]]; then
                log_error "--- Last 100 lines of password-change log ---"
                tail -100 "$password_change_log" 2>/dev/null | while IFS= read -r line; do log_error "  $line"; done
            fi
            return 1
        }

        log_info "Step 1.5: Mounting VMware Tools ISO..."
        sleep 10
        local tools_mount_log="$SCRIPT_DIR/logs/vmware-tools-mount-$(date +%Y%m%d-%H%M%S).log"
        mkdir -p "$(dirname "$tools_mount_log")"
        export GOVC_USERNAME="$vcenter_user"
        export GOVC_PASSWORD="$vcenter_pass"
        run_script "$scripts_dir/mount-vmware-tools.sh" "$vm_name" "$tools_mount_log" || {
            log_error "VMware Tools mount failed."
            if [[ -f "$tools_mount_log" ]]; then
                log_error "--- Last 100 lines of vmware-tools-mount log ---"
                tail -100 "$tools_mount_log" 2>/dev/null | while IFS= read -r line; do log_error "  $line"; done
            fi
            return 1
        }

        log_info "Step 1.6: Installing VMware Tools..."
        local tools_install_log="$SCRIPT_DIR/logs/vmware-tools-install-$(date +%Y%m%d-%H%M%S).log"
        mkdir -p "$(dirname "$tools_install_log")"
        run_script "$scripts_dir/install-vmware-tools-keystrokes.sh" "$vm_name" "$tools_install_log" || {
            log_error "VMware Tools installation failed."
            if [[ -f "$tools_install_log" ]]; then
                log_error "--- Last 100 lines of vmware-tools-install log ---"
                tail -100 "$tools_install_log" 2>/dev/null | while IFS= read -r line; do log_error "  $line"; done
            fi
            return 1
        }

        # Step 1.6b: Poll vm.info guest block for tools installation success (solid state, no guest.start).
        log_info "Step 1.6b: Waiting for VMware Tools to report ready (guestOperationsReady + toolsRunningStatus, poll up to 10 min)..."
        if ! wait_for_vm_tools_ready "$vm_name" 600; then
            log_error "VMware Tools did not report ready within 600s (govc vm.info guest block)."
            return 1
        fi
        log_success "VMware Tools ready (guestOperationsReady=true, toolsRunningStatus=guestToolsRunning)."

        # Step 1.7: Poll until guest ops work. Fail immediately on auth error; otherwise keep waiting.
        # Capture govc errors so we can report why verification failed (auth vs Tools/PowerShell).
        log_info "Step 1.7: Checking password change: waiting for VMware Tools guest operations (poll up to 10 min, every 30s). Failing immediately on auth error..."
        local guest_ready=0
        local wait_elapsed=0
        local wait_timeout=600
        local wait_interval=30
        local govc_guest_opts=(-vm "$vm_name" -l "${windows_username}:${windows_password}")
        local ps_exe="C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
        local last_start_stderr=""
        local last_ps_exit_code=""
        local tmp_stderr
        tmp_stderr=$(mktemp 2>/dev/null) || tmp_stderr=""
        while [[ $wait_elapsed -lt $wait_timeout ]]; do
            last_start_stderr=""
            last_ps_exit_code=""
            local pid
            if [[ -n "$tmp_stderr" ]]; then
                pid=$(govc guest.start "${govc_guest_opts[@]}" "$ps_exe" "-ExecutionPolicy" "Bypass" "-NoProfile" "-NoLogo" "-NonInteractive" "-Command" "exit 0" 2>"$tmp_stderr") || true
                last_start_stderr=$(cat "$tmp_stderr" 2>/dev/null)
            else
                pid=$(govc guest.start "${govc_guest_opts[@]}" "$ps_exe" "-ExecutionPolicy" "Bypass" "-NoProfile" "-NoLogo" "-NonInteractive" "-Command" "exit 0" 2>/dev/null) || true
            fi
            if [[ -n "$pid" ]]; then
                local raw
                raw=$(govc guest.ps "${govc_guest_opts[@]}" -p "$pid" -X -x 2>/dev/null) || true
                local code
                code=$(echo "$raw" | awk -v p="$pid" 'NR>1 && $2+0==p+0 {print $5; exit}')
                [[ -z "$code" ]] && code=$(echo "$raw" | grep -o '"exitCode":[0-9]*' | head -1 | sed 's/"exitCode"://')
                last_ps_exit_code="${code:-}"
                if [[ "${code:-1}" == "0" ]]; then
                    guest_ready=1
                    log_success "Password change verified: guest operations ready after ${wait_elapsed}s."
                    break
                fi
            else
                # No PID: check for auth error and fail immediately.
                if [[ -n "$last_start_stderr" ]]; then
                    local err_lower
                    err_lower=$(echo "$last_start_stderr" | tr '[:upper:]' '[:lower:]')
                    if echo "$err_lower" | grep -qE 'auth|login|credential|permission denied|access denied|invalid.*password|logon|unauthorized|supplied credentials|authenticate'; then
                        log_error "Password change check failed: authentication error (fail immediately). Wrong password or user not logged in."
                        log_error "Govc error: $last_start_stderr"
                        rm -f "$tmp_stderr" 2>/dev/null || true
                        return 1
                    fi
                fi
            fi
            log_info "Guest PowerShell not ready yet, waiting ${wait_interval}s (elapsed ${wait_elapsed}s / ${wait_timeout}s)..."
            sleep $wait_interval
            wait_elapsed=$((wait_elapsed + wait_interval))
        done
        rm -f "$tmp_stderr" 2>/dev/null || true

        if [[ $guest_ready -ne 1 ]]; then
            # Classify failure for clearer diagnostics.
            local reason="unknown"
            local detail=""
            if [[ -n "$last_ps_exit_code" && "$last_ps_exit_code" != "0" ]]; then
                reason="powershell_error"
                detail="Guest process ran but PowerShell exited with code ${last_ps_exit_code} (Tools may be running but command or login state failed)."
            elif [[ -n "$last_start_stderr" ]]; then
                local err_lower
                err_lower=$(echo "$last_start_stderr" | tr '[:upper:]' '[:lower:]')
                if echo "$err_lower" | grep -qE 'auth|login|credential|permission denied|access denied|invalid.*password|logon|unauthorized|supplied credentials|authenticate'; then
                    reason="auth_error"
                    detail="Authentication failed: wrong password or user not logged in. Govc error: $last_start_stderr"
                elif echo "$err_lower" | grep -qE 'tools|guest oper|not available|not running|not installed|timeout|connection|no route'; then
                    reason="tools_not_ready"
                    detail="VMware Tools not ready or guest operations unavailable. Govc error: $last_start_stderr"
                else
                    reason="guest_error"
                    detail="Guest start failed. Govc error: $last_start_stderr"
                fi
            else
                detail="No guest process started and no govc error captured (guest.start returned no PID within ${wait_timeout}s)."
            fi
            log_error "Password change check failed after ${wait_timeout}s."
            log_error "Failure reason: $reason — $detail"
            return 1
        fi
    else
        # target_ready_mode: template or existing_base; target VM already has Tools
        log_info "Step 1: Skipping password change and VMware Tools (template/existing_base: target already has Tools)"
        sleep 10
    fi

    # Template/existing_base only: wait for guest operations before Step 2 (guest.upload needs agent contactable).
    if [[ "$target_ready_mode" == "true" ]]; then
        log_info "Waiting for VM to be powered on and guest operations agent ready (template/existing_base)..."
        local power_state
        power_state=$(get_vm_power_state "$vm_name")
        if [[ "$power_state" != "poweredOn" ]]; then
            log_info "Powering on VM: $vm_name"
            govc vm.power -on "$vm_name" >/dev/null 2>&1 || { log_error "Failed to power on $vm_name"; return 1; }
            local power_wait=0
            while [[ $power_wait -lt 120 ]]; do
                power_state=$(get_vm_power_state "$vm_name")
                [[ "$power_state" == "poweredOn" ]] && break
                sleep 5
                power_wait=$((power_wait + 5))
            done
            [[ "$power_state" != "poweredOn" ]] && { log_error "VM did not reach poweredOn within 120s"; return 1; }
        fi
        log_info "Waiting for guest operations agent (poll up to 10 min)..."
        if ! wait_for_vm_guest_ready "$vm_name" 600; then
            log_error "Guest operations agent could not be contacted within 600s. Ensure VMware Tools is running and the VM has finished booting."
            return 1
        fi
        log_success "Guest operations agent ready."
    fi

    # Step 2: Configure network. (template/existing_base: vm_name is target; ISO: on base VM, target gets no network.)
    if [[ "$target_ready_mode" == "true" ]]; then
        log_info "Step 2: Configuring network on target VM ($vm_name)..."
    else
        log_info "Step 2: Configuring network on base VM ($vm_name) (ISO mode; target will be created in Step 3.5)..."
    fi
    
    local static_ip=$(get_var "$vars_file" "static_ip")
    local subnet_mask=$(get_var "$vars_file" "subnet_mask")
    local gateway=$(get_var "$vars_file" "gateway")
    local dns_servers=$(sed -n 's/.*dns_servers *= *\[\(.*\)\]/(\1)/p' "$vars_file" | sed 's/ //g')
    
    # Export environment variables for PowerShell script
    export STATIC_IP="$static_ip"
    export SUBNET_MASK="$subnet_mask"
    export GATEWAY="$gateway"
    export DNS_SERVERS="$dns_servers"
    export PS_ENV_VARS="STATIC_IP,SUBNET_MASK,GATEWAY,DNS_SERVERS"
    
    local network_log="$SCRIPT_DIR/logs/network-config-$(date +%Y%m%d-%H%M%S).log"
    mkdir -p "$(dirname "$network_log")"
    log_info "Network configuration log: $network_log"
    
    run_script "$scripts_dir/run-powershell-via-govc.sh" "$vm_name" "$scripts_dir/configure-network-manual.ps1" "$windows_username" "$windows_password" "$network_log" || {
        log_error "Network configuration failed."
        if [[ -f "$network_log" ]]; then
            log_error "--- Last 200 lines of network config log ($network_log) ---"
            tail -200 "$network_log" 2>/dev/null | while IFS= read -r line; do log_error "  $line"; done
        fi
        return 1
    }
    
    # Step 3: Install Windows updates. (template/existing_base: on target; ISO: on base VM, target gets no updates.)
    if [[ "$target_ready_mode" == "true" ]]; then
        log_info "Step 3: Installing Windows updates on target VM ($vm_name)..."
    else
        log_info "Step 3: Installing Windows updates on base VM ($vm_name) (ISO mode)..."
    fi
    local enable_updates=$(get_var "$vars_file" "enable_windows_updates")
    
    if [[ "$enable_updates" == "true" ]]; then
        local updates_log="$SCRIPT_DIR/logs/windows-updates-$(date +%Y%m%d-%H%M%S).log"
        mkdir -p "$(dirname "$updates_log")"
        log_info "Windows updates log: $updates_log"
        
        run_script "$scripts_dir/run-windows-updates-loop.sh" "$vm_name" "$windows_username" "$windows_password" 10 > "$updates_log" 2>&1 || {
            log_error "Windows updates installation failed."
            if [[ -f "$updates_log" ]]; then
                log_error "--- Last 300 lines of windows-updates log ($updates_log) ---"
                tail -300 "$updates_log" 2>/dev/null | while IFS= read -r line; do log_error "  $line"; done
            fi
            return 1
        }
    else
        log_info "Windows updates disabled (enable_windows_updates=false)"
    fi

    # Step 3.5: ISO only — clone base VM to target (windows-target-vm-{timestamp}). Template/existing_base: target already set in main, no clone.
    if [[ "$build_mode" == "iso" ]]; then
        log_info "Step 3.5: Cloning base VM to target VM (windows-target-vm-{timestamp}) for stembuild..."
        local target_vm_name
        target_vm_name=$(clone_current_vm_to_target "$vm_name" "$vars_file") || return 1
        target_vm_name=$(printf '%s' "$target_vm_name" | tr -d '\r\n' | sed -e 's/^[[:space:]"'\'']*//' -e 's/[[:space:]"'\'']*$//')
        log_info "Target VM: $target_vm_name (stembuild and package on target; network/updates were on base)"
        vm_name="$target_vm_name"
        CLEANUP_TARGET_VM_NAME="$target_vm_name"
    else
        log_info "Step 3.5: No clone (template/existing_base: target VM already set)"
    fi

    # Step 3.6: Ensure target VM is powered on and guest ops ready. From here on all modes run stembuild construct and package on this VM.
    log_info "Step 3.6: Waiting for VM to boot and guest operations ready..."
    local power_state
    power_state=$(get_vm_power_state "$vm_name")
    if [[ "$power_state" != "poweredOn" ]]; then
        log_info "Powering on target VM: $vm_name"
        govc vm.power -on "$vm_name" >/dev/null 2>&1 || { log_error "Failed to power on $vm_name"; return 1; }
        local power_wait=0
        while [[ $power_wait -lt 120 ]]; do
            power_state=$(get_vm_power_state "$vm_name")
            if [[ "$power_state" == "poweredOn" ]]; then
                log_success "Target VM powered on after ${power_wait}s"
                break
            fi
            sleep 5
            power_wait=$((power_wait + 5))
        done
        if [[ "$power_state" != "poweredOn" ]]; then
            log_error "Target VM did not reach poweredOn within 120s (state: $power_state)"
            return 1
        fi
    else
        log_info "Target VM already powered on"
    fi
    log_info "Waiting for guest operations on target VM (poll up to 10 min, every 30s)..."
    if ! wait_for_vm_guest_ready "$vm_name" 600; then
        log_error "Target VM guest operations did not become ready within 600s."
        return 1
    fi
    log_success "Target VM guest operations ready."

    # Run stembuild construct (with retry: on failure, restart target VM and try again)
    local max_attempts="${STEMBUILD_CONSTRUCT_MAX_ATTEMPTS:-2}"
    local attempt=1
    local construct_rc=0
    if [[ -z "$patch_version" ]]; then
        log_error "patch_version is required for stembuild"
        return 1
    fi
    local stembuild_binary=""
    if command -v stembuild &> /dev/null; then
        stembuild_binary=$(command -v stembuild)
    else
        log_error "stembuild not found in PATH"
        return 1
    fi
    # datacenter already set in initial extraction above
    mkdir -p "$SCRIPT_DIR/logs"

    while [[ $attempt -le $max_attempts ]]; do
        log_info "Step 4: Running stembuild construct (attempt $attempt of $max_attempts)..."
        local construct_log="$SCRIPT_DIR/logs/stembuild-construct-$(date +%Y%m%d-%H%M%S)-attempt${attempt}.log"
        construct_rc=0

        if [[ -n "${jumper_ip:-}" ]] && [[ -n "${jumper_user:-}" ]] && [[ -n "${jumper_password:-}" ]]; then
        # Copy all scripts and binaries required for remote execution. run-stembuild-construct.sh sources govc-vm-utils.sh from same directory.
        local lgpo_zip="${LGPO_ZIP:-$SCRIPT_DIR/LGPO.zip}"
        [[ -f "$lgpo_zip" ]] || lgpo_zip="LGPO.zip"
        if [[ ! -f "$lgpo_zip" ]]; then
            log_error "LGPO.zip not found (looked for $SCRIPT_DIR/LGPO.zip and ./LGPO.zip). Set LGPO_ZIP or place LGPO.zip in script directory for jumper mode."
            return 1
        fi
        [[ -f "$scripts_dir/govc-vm-utils.sh" ]] || { log_error "govc-vm-utils.sh not found at $scripts_dir/govc-vm-utils.sh (required for jumper)"; return 1; }
        local stembuild_bin govc_bin
        stembuild_bin=$(which stembuild 2>/dev/null) || { log_error "stembuild not in PATH for jumper copy"; return 1; }
        govc_bin=$(which govc 2>/dev/null) || { log_error "govc not in PATH for jumper copy"; return 1; }
        local stembuild_remote="\$HOME/stembuild"
        log_info "Copying required scripts and binaries to jumper: run-stembuild-construct.sh, govc-vm-utils.sh, stembuild, govc, LGPO.zip"
        if ! sshpass -p "$jumper_password" scp -o StrictHostKeyChecking=no \
            "$scripts_dir/run-stembuild-construct.sh" \
            "$scripts_dir/govc-vm-utils.sh" \
            "$stembuild_bin" \
            "$govc_bin" \
            "$lgpo_zip" \
            "$jumper_user@$jumper_ip:~/"; then
            log_error "Failed to copy required files to jumper (run-stembuild-construct.sh, govc-vm-utils.sh, stembuild, govc, LGPO.zip)"
            return 1
        fi
        # Optional: copy vCenter CA cert to jumper if construct needs it
        local vcenter_ca_remote=""
        if [[ -n "${VCENTER_CA_CERTS:-}" ]] && [[ -f "${VCENTER_CA_CERTS}" ]]; then
            if sshpass -p "$jumper_password" scp -o StrictHostKeyChecking=no "$VCENTER_CA_CERTS" "$jumper_user@$jumper_ip:~/vcenter-ca-certs.pem"; then
                vcenter_ca_remote="\$HOME/vcenter-ca-certs.pem"
            fi
        fi
        # Export GOVC_* and PATH on remote; capture all output to local log so we can show it on failure.
        local export_vars="PATH=\"\$HOME:\$PATH\" GOVC_URL=\"$GOVC_URL\" GOVC_USERNAME=\"$GOVC_USERNAME\" GOVC_PASSWORD=\"$GOVC_PASSWORD\" GOVC_INSECURE=\"${GOVC_INSECURE:-}\""
        [[ -n "$vcenter_ca_remote" ]] && export_vars="$export_vars VCENTER_CA_CERTS=\"$vcenter_ca_remote\""
        log_info "Starting stembuild construct on jumper via SSH ($jumper_user@$jumper_ip); output below..."
        sshpass -p "$jumper_password" ssh -o StrictHostKeyChecking=no "$jumper_user@$jumper_ip" \
            "echo '--- SSH session started on jumper, running stembuild construct ---'; export $export_vars; chmod +x ~/run-stembuild-construct.sh ~/stembuild ~/govc; bash ~/run-stembuild-construct.sh \"$vm_name\" \"$static_ip\" \"$windows_username\" \"$windows_password\" \"$stembuild_remote\" \"$datacenter\"" 2>&1 | tee "$construct_log"
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            construct_rc=1
            log_error "stembuild construct failed on jumper (attempt $attempt). Last 200 lines of log:"
            if [[ -f "$construct_log" ]]; then
                tail -200 "$construct_log" 2>/dev/null | while IFS= read -r line; do log_error "  $line"; done
            fi
        else
            log_success "stembuild construct completed on jumper"
        fi
    else
        run_script "$scripts_dir/run-stembuild-construct.sh" "$vm_name" "$static_ip" "$windows_username" "$windows_password" "$stembuild_binary" "$datacenter" "$construct_log" || construct_rc=$?
        if [[ $construct_rc -ne 0 ]]; then
            log_error "stembuild construct failed (attempt $attempt)."
            if [[ -f "$construct_log" ]]; then
                log_error "--- Last 200 lines of stembuild-construct log ---"
                tail -200 "$construct_log" 2>/dev/null | while IFS= read -r line; do log_error "  $line"; done
            fi
        else
            log_success "stembuild construct completed"
        fi
    fi

        if [[ $construct_rc -eq 0 ]]; then
            break
        fi
        if [[ $attempt -ge $max_attempts ]]; then
            log_error "stembuild construct failed after $max_attempts attempt(s)."
            return 1
        fi
        log_warn "Restarting target VM and retrying stembuild construct (attempt $((attempt + 1)) of $max_attempts)..."
        if ! vm_reboot_shutdown_poweron "$vm_name" 120; then
            log_error "Failed to restart target VM (power off/on)."
            return 1
        fi
        log_info "Waiting for guest to be ready after restart (poll up to 10 min)..."
        if ! wait_for_vm_guest_ready "$vm_name" 600; then
            log_error "Target VM guest operations did not become ready after restart."
            return 1
        fi
        log_success "Target VM ready after restart, retrying stembuild construct."
        attempt=$((attempt + 1))
    done

    
    # : Run stembuild package
    log_info "Step 5: Running stembuild package..."
    local package_log="$SCRIPT_DIR/logs/stembuild-package-$(date +%Y%m%d-%H%M%S).log"
    mkdir -p "$(dirname "$package_log")"
    
    # Resolve VM to inventory path for stembuild package
    local vm_inventory_path
    vm_inventory_path=$(find_vm_inventory_path "$vm_name" "$datacenter") || return 1

    # Stop VM before packaging (required by stembuild)
    log_info "Stopping VM before packaging..."
    if ! vm_power_off "$vm_name" 300 1; then
        log_error "VM did not power off within timeout"
        return 1
    fi
    log_success "VM powered off"
    
    # Run package (pass vCenter options so package script has what it needs)
    local package_args=(-n "$vm_name" -P "$patch_version" -i "$vm_inventory_path")
    [[ "$vcenter_insecure" == "true" ]] && package_args+=(-I)
    [[ -n "${VCENTER_CA_CERTS:-}" ]] && [[ -f "${VCENTER_CA_CERTS}" ]] && package_args+=(-c "$VCENTER_CA_CERTS")
    run_script "$SCRIPT_DIR/package-stemcell.sh" "${package_args[@]}" > "$package_log" 2>&1 || {
        log_error "stembuild package failed."
        if [[ -f "$package_log" ]]; then
            log_error "--- Last 200 lines of stembuild-package log ---"
            tail -200 "$package_log" 2>/dev/null | while IFS= read -r line; do log_error "  $line"; done
        fi
        return 1
    }
    
    # Find generated stemcell file
    local stemcell_file=$(ls -t bosh-stemcell-*-vsphere-esxi-*-go_agent.tgz 2>/dev/null | head -n1)
    if [[ -n "$stemcell_file" ]]; then
        log_success "Stemcell created: $stemcell_file"
    fi
    
    # Step 8: Create template from VM only in ISO mode when template_name (or template_path) is provided.
    # Template mode: we do not create a new template; we only use the template to create a VM, then clean it up.
    # Existing_base mode: we do not create a template. vcenter_folder is optional; template_name takes precedence.
    if [[ "$build_mode" == "iso" ]] && ([[ -n "$template_path" ]] || [[ -n "$template_name" ]]); then
        log_info "Step 8: Creating template from VM (ISO mode; template_name/template_path set)..."

        # Ensure VM is powered off (should be after stembuild package)
        if [[ "$(get_vm_power_state "$vm_name")" != "poweredOff" ]]; then
            log_info "VM is not powered off, shutting down..."
            if ! vm_power_off "$vm_name" 300 1; then
                log_error "VM did not power off within timeout"
                return 1
            fi
            log_success "VM powered off"
        else
            log_info "VM is already powered off (from stembuild package)"
        fi

        # Detach ISO from CD-ROM before templatizing (govc device.cdrom.eject requires VM powered on)
        log_info "Detaching CD-ROM/ISO from VM before creating template..."
        govc vm.power -on "$vm_name" >/dev/null 2>&1 || true
        local power_wait=0
        while [[ $power_wait -lt 60 ]]; do
            [[ "$(get_vm_power_state "$vm_name")" == "poweredOn" ]] && break
            sleep 5
            power_wait=$((power_wait + 5))
        done
        if [[ "$(get_vm_power_state "$vm_name")" == "poweredOn" ]]; then
            govc device.cdrom.eject -vm "$vm_name" 2>/dev/null || log_warn "CD-ROM eject failed or no CD-ROM (non-fatal)"
            vm_power_off "$vm_name" 120 1 >/dev/null 2>&1 || true
            power_wait=0
            while [[ $power_wait -lt 120 ]]; do
                [[ "$(get_vm_power_state "$vm_name")" == "poweredOff" ]] && break
                sleep 5
                power_wait=$((power_wait + 5))
            done
        fi
        log_info "VM powered off, ready for template conversion."

        # Resolve inventory path before markastemplate (find may not return templates in some setups)
        local vm_path
        vm_path=$(find_vm_inventory_path "$vm_name" "$datacenter") || true

        # Convert to template
        log_info "Converting VM to template..."
        local final_template_name="${template_name:-${vm_name}-template}"
        govc vm.markastemplate "$vm_name" || {
            log_error "Template conversion failed"
            return 1
        }

        # Rename template if custom name provided (govc object.rename PATH NEW_NAME; vm.rename does not exist)
        if [[ -n "$template_name" ]] && [[ "$template_name" != "${vm_name}-template" ]] && [[ -n "$vm_path" ]]; then
            log_info "Renaming template to: $template_name"
            if [[ -n "$datacenter" ]]; then
                govc object.rename -dc "$datacenter" "$vm_path" "$template_name" || {
                    log_warn "Template rename failed (non-critical)"
                }
            else
                govc object.rename "$vm_path" "$template_name" || {
                    log_warn "Template rename failed (non-critical)"
                }
            fi
            final_template_name="$template_name"
        elif [[ -n "$template_name" ]] && [[ "$template_name" != "${vm_name}-template" ]] && [[ -z "$vm_path" ]]; then
            log_warn "Could not resolve VM path for rename (non-critical)"
            final_template_name="$template_name"
        fi

        # If vcenter_folder is set, move template to that folder; otherwise it stays in same folder as VM
        if [[ -n "$vcenter_folder" ]] && [[ -n "$vm_path" ]]; then
            local template_current_path
            if [[ -n "$template_name" ]] && [[ "$template_name" != "${vm_name}-template" ]]; then
                template_current_path="${vm_path%/*}/$template_name"
            else
                template_current_path="$vm_path"
            fi
            log_info "Moving template to folder: $vcenter_folder"
            if [[ -n "$datacenter" ]]; then
                govc object.mv -dc "$datacenter" "$template_current_path" "$vcenter_folder" || {
                    log_warn "Template move to $vcenter_folder failed (non-critical)"
                }
            else
                govc object.mv "$template_current_path" "$vcenter_folder" || {
                    log_warn "Template move to $vcenter_folder failed (non-critical)"
                }
            fi
        fi

        log_success "Template created: $final_template_name"
    fi
    
    # Step 9: Cleanup
    # create_template = we converted the stembuild VM to a template (only in ISO mode when template_name/template_path set). Do not delete it.
    # When template_name is set in ISO mode it takes precedence: VM is marked as template, so we do not delete it; keep_base_vm only affects base VM.
    local create_template=false
    if [[ "$build_mode" == "iso" ]] && ([[ -n "$template_path" ]] || [[ -n "$template_name" ]]); then
        create_template=true
    fi

    # On all modes (ISO, template, existing_base): delete the VM we used for stembuild unless we converted it to a template
    if [[ "$create_template" != "true" ]]; then
        log_info "Step 9: Cleaning up VM (not converted to template): $vm_name"
        if vm_exists "$vm_name"; then
            if [[ "$(get_vm_power_state "$vm_name")" != "poweredOff" ]]; then
                log_info "Shutting down before cleanup..."
                vm_power_off "$vm_name" 120 0 || true
            fi
            log_info "Deleting VM: $vm_name"
            govc vm.destroy "$vm_name" >/dev/null 2>&1 || {
                log_warn "Failed to delete VM (may require manual cleanup): $vm_name"
            }
            log_success "VM cleaned up"
        else
            log_info "VM not found (already deleted or not created)"
        fi
    fi

    # ISO mode only: delete base VM if KEEP_BASE_VM is not true. keep_base_vm has no effect in template or existing_base mode (we never touch the user's base/source VM).
    if [[ "$build_mode" == "iso" ]] && [[ -n "$base_vm_name" ]] && [[ "$base_vm_name" != "$vm_name" ]] && [[ "${keep_base_vm}" != "true" ]]; then
        log_info "Step 9 (ISO mode): Cleaning up base VM (keep_base_vm=false): $base_vm_name"
        if vm_exists "$base_vm_name"; then
            if [[ "$(get_vm_power_state "$base_vm_name")" != "poweredOff" ]]; then
                vm_power_off "$base_vm_name" 120 0 || true
            fi
            govc vm.destroy "$base_vm_name" >/dev/null 2>&1 || {
                log_warn "Failed to delete base VM (may require manual cleanup): $base_vm_name"
            }
            log_success "Base VM cleaned up"
        fi
    elif [[ "$build_mode" == "iso" ]] && [[ "${keep_base_vm}" == "true" ]]; then
        log_info "Step 9 (ISO mode): Keeping base VM (keep_base_vm=true)"
    fi

    log_success "Stemcell creation completed successfully"
    return 0
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build Windows Server 2019 VM for vSphere using Packer

OPTIONS:
    -v, --vars-file FILE    Path to variables file (default: variables.pkrvars.hcl)
    -l, --log-level LEVEL   Logging level: DEBUG, INFO, WARN, ERROR (default: INFO)
    -i, --init-only         Only initialize Packer plugins
    -c, --validate-only     Only validate Packer configuration
    --debug                 Enable set -x (trace) for this script and all scripts it calls
    --overwrite             Force upload ISO even if it already exists on datastore
    -h, --help              Show this help message

EXAMPLES:
    # Build with default variables file
    $0

    # Build with custom variables file
    $0 -v my-variables.pkrvars.hcl

    # Build with debug logging
    $0 -l DEBUG

    # Initialize plugins only
    $0 -i

    # Validate configuration only
    $0 -c

ENVIRONMENT VARIABLES:
    LOG_LEVEL               Set default log level (DEBUG, INFO, WARN, ERROR)
    DEBUG_MODE              If "true", same as --debug (set -x for this script and child scripts)

NOTES:
    - Copy variables.pkrvars.hcl.example to variables.pkrvars.hcl and configure it
    - Ensure Windows Server 2019 ISO is uploaded to vSphere datastore
    - Build process may take 30-60 minutes depending on Windows updates
    - All logs are saved to the logs/ directory

EOF
}

# Main function
main() {
    local vars_file=""
    local log_level="${LOG_LEVEL:-INFO}"
    local init_only=false
    local validate_only=false
    local overwrite_iso=false
    local skip_packer_init=false
    local debug_mode=false
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-packer-init)
                skip_packer_init=true
                shift
                ;;
            --debug)
                debug_mode=true
                shift
                ;;
            -v|--vars-file)
                vars_file="$2"
                shift 2
                ;;
            -l|--log-level)
                log_level="$2"
                shift 2
                ;;
            -i|--init-only)
                init_only=true
                shift
                ;;
            -c|--validate-only)
                validate_only=true
                shift
                ;;
            --overwrite)
                overwrite_iso=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --jumper-ip)
                jumper_ip=$2
                shift 2
                ;;
            --jumper-password)
                jumper_password=$2
                shift 2
                ;;
            --jumper-user)
                jumper_user=$2
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Banner
    echo ""
    echo "=========================================="
    echo "  Windows Stemcell Creation Script"
    echo "=========================================="
    echo ""

    # Enable trace (set -x) for this script and export DEBUG_MODE so run_script uses bash -x for child scripts
    if [[ "$debug_mode" == true ]] || [[ "${DEBUG_MODE:-}" == "true" ]]; then
        set -x
        export DEBUG_MODE=true
    fi

    # Check prerequisites
    check_prerequisites
    
    if [[ $skip_packer_init == false ]]; then
        # Initialize Packer
        init_packer
    fi
    
    if [[ "$init_only" == true ]]; then
        log_success "Initialization complete"
        exit 0
    fi
    
    # Use default variables file if not specified
    if [[ -z "$vars_file" ]] && [[ -f "variables.pkrvars.hcl" ]]; then
        vars_file="variables.pkrvars.hcl"
        log_info "Using default variables file: $vars_file"
    fi

    # --- Detect mode: one of iso | template | existing_base (preference order) ---
    [[ -f "$vars_file" ]] || { log_error "Vars file not found: $vars_file"; exit 1; }
    local iso_path_val iso_path_local_val template_path_early existing_base_vm_name build_source_mode
    iso_path_val=$(trim_var "$(get_var "$vars_file" "iso_path")")
    iso_path_local_val=$(trim_var "$(get_var "$vars_file" "iso_path_local")")
    template_path_early=$(trim_var "$(get_var "$vars_file" "template_path")")
    existing_base_vm_name=$(trim_var "$(get_var "$vars_file" "existing_base_vm_name")")
    # Treat empty-like values as unset (e.g. '' or "" so missing keys / empty values do not force ISO)
    [[ "$iso_path_val" == "''" ]] || [[ "$iso_path_val" == '""' ]] && iso_path_val=""
    [[ "$iso_path_local_val" == "''" ]] || [[ "$iso_path_local_val" == '""' ]] && iso_path_local_val=""
    [[ "$template_path_early" == "''" ]] || [[ "$template_path_early" == '""' ]] && template_path_early=""
    [[ "$existing_base_vm_name" == "''" ]] || [[ "$existing_base_vm_name" == '""' ]] && existing_base_vm_name=""
    if [[ -n "$iso_path_val" ]] || [[ -n "$iso_path_local_val" ]]; then
        build_source_mode="iso"
    elif [[ -n "$template_path_early" ]]; then
        build_source_mode="template"
    elif [[ -n "$existing_base_vm_name" ]]; then
        build_source_mode="existing_base"
    else
        log_error "Build source missing: set one of iso_path/iso_path_local, template_path, or existing_base_vm_name (preference: ISO > template > existing_base)"
        exit 1
    fi
    log_info "Mode: $build_source_mode"

    # Proxy must be set before any govc command (all branches and cleanup_on_failure use govc).
    setup_proxy_environment "$vars_file"

    # === BRANCH: existing_base ===
    if [[ "$build_source_mode" == "existing_base" ]]; then
        export_govc_from_vars "$vars_file"
        if ! vm_exists "$existing_base_vm_name"; then
            log_error "Existing base VM not found: $existing_base_vm_name"
            exit 1
        fi
        CLEANUP_VM_NAME=""
        CLEANUP_TARGET_VM_NAME=""
        CLEANUP_VARS_FILE="$vars_file"
        CLEANUP_BUILD_MODE="existing_base"
        CLEANUP_ALREADY_RAN=false
        CLEANUP_ENABLED=true
        trap 'exit_code=$?; if [[ $exit_code -ne 0 ]] && [[ "$CLEANUP_ENABLED" == "true" ]]; then cleanup_on_failure $exit_code; fi' EXIT
        local target_vm_name
         # Power off existing base VM before clone (third arg true); clone_current_vm_to_target will power off then clone.
        target_vm_name=$(clone_current_vm_to_target "$existing_base_vm_name" "$vars_file" "true") || exit 1
        target_vm_name=$(printf '%s' "$target_vm_name" | tr -d '\r\n' | sed -e 's/^[[:space:]"'\'']*//' -e 's/[[:space:]"'\'']*$//')
        CLEANUP_TARGET_VM_NAME="$target_vm_name"
        post_build_provisioning "$vars_file" "$target_vm_name" "existing_base" "$log_level"
        CLEANUP_ENABLED=false
        log_success "Done (existing_base mode)"
        exit 0
    fi

    # === BRANCH: template ===
    if [[ "$build_source_mode" == "template" ]]; then
        if [[ "$validate_only" == true ]]; then
            log_success "Validation complete (template mode)"
            exit 0
        fi
        export_govc_from_vars "$vars_file"
        local template_inventory_path="$template_path_early"
        if [[ -n "$template_path_early" ]] && [[ "$template_path_early" != /* ]]; then
            local tpl_dc; tpl_dc=$(trim_var "$(get_var "$vars_file" "vcenter_datacenter")")
            template_inventory_path=$(find_vm_inventory_path "$template_path_early" "$tpl_dc") || template_inventory_path="$template_path_early"
            [[ "$template_inventory_path" != "$template_path_early" ]] && log_info "Template path: $template_inventory_path"
        fi
        local timestamp_early vm_name_final
        timestamp_early=$(date -u +"%Y%m%d%H%M%S" 2>/dev/null || date +"%Y%m%d%H%M%S" 2>/dev/null || echo "")
        vm_name_final="windows-target-vm-${timestamp_early}"
        local clone_opts=(-vm "$template_inventory_path" -on=true)
        local tpl_dc tpl_ds tpl_folder
        tpl_dc=$(trim_var "$(get_var "$vars_file" "vcenter_datacenter")")
        tpl_ds=$(trim_var "$(get_var "$vars_file" "vcenter_datastore")")
        tpl_folder=$(trim_var "$(get_var "$vars_file" "vcenter_folder")")
        [[ -n "$tpl_dc" ]] && clone_opts+=(-dc "$tpl_dc")
        [[ -n "$tpl_ds" ]] && clone_opts+=(-ds "$tpl_ds")
        [[ -n "$tpl_folder" ]] && clone_opts+=(-folder "$tpl_folder")
        if ! govc vm.clone "${clone_opts[@]}" "$vm_name_final" 1>&2; then
            log_error "govc vm.clone from template failed"
            exit 1
        fi
        local vm_wait_t=0
        while [[ $vm_wait_t -lt 300 ]]; do
            vm_exists "$vm_name_final" && break
            sleep 5
            vm_wait_t=$((vm_wait_t + 5))
        done
        if ! vm_exists "$vm_name_final"; then
            log_error "Target VM not found after clone: $vm_name_final"
            exit 1
        fi
        CLEANUP_VM_NAME="$vm_name_final"
        CLEANUP_TARGET_VM_NAME=""
        CLEANUP_VARS_FILE="$vars_file"
        CLEANUP_BUILD_MODE="template"
        CLEANUP_ALREADY_RAN=false
        CLEANUP_ENABLED=true
        trap 'exit_code=$?; if [[ $exit_code -ne 0 ]] && [[ "$CLEANUP_ENABLED" == "true" ]]; then cleanup_on_failure $exit_code; fi' EXIT
        post_build_provisioning "$vars_file" "$vm_name_final" "template" "$log_level"
        CLEANUP_ENABLED=false
        log_success "Done (template mode)"
        exit 0
    fi

    # === BRANCH: ISO (Packer + post-build provisioning) ===
    if [[ "$build_source_mode" != "iso" ]]; then
        log_error "Unexpected mode: $build_source_mode"
        exit 1
    fi
    # Autounattend: ISO only
    if ! process_autounattend_template "$vars_file"; then
        log_error "Failed to process Autounattend.xml template"
        exit 1
    fi
    local processed_file="$SCRIPT_DIR/http/Autounattend.processed.xml"
    [[ -f "$processed_file" ]] && [[ -r "$processed_file" ]] || {
        log_error "Processed Autounattend.xml not found or not readable: $processed_file"
        exit 1
    }
    # Fail fast before Packer: ensure no unreplaced placeholders (catches template/build.sh mismatch)
    if grep -q '{{\.' "$processed_file" 2>/dev/null; then
        log_error "Processed Autounattend.xml still contains unreplaced placeholders ({{.}}). Check template and process_autounattend_template."
        grep -n '{{\.' "$processed_file" 2>/dev/null | while IFS= read -r line; do log_error "  $line"; done
        exit 1
    fi

    # Set guest OS type once (vSphere or fallback); validate and build use PKR_VAR_guest_os_type as-is
    set_packer_guest_os_type "$vars_file"

    validate_iso_config "$vars_file" "$overwrite_iso"
    
    validate_packer "$vars_file"

    # ISO: set VM timestamp for Packer (vm_name_final = vm_name_base-timestamp is set in build_vm)
    if [[ -n "$vars_file" ]] && [[ -f "$vars_file" ]]; then
        local vm_name_base vcenter_server
        vm_name_base=$(trim_var "$(get_var "$vars_file" "vm_name")")
        vcenter_server=$(get_var "$vars_file" "vcenter_server")
        if [[ -n "$vm_name_base" ]] && [[ -n "$vcenter_server" ]]; then
            local timestamp=$(date -u +"%Y%m%d%H%M%S" 2>/dev/null || date +"%Y%m%d%H%M%S" 2>/dev/null || echo "")
            export PKR_VAR_build_timestamp="$timestamp"
        fi
    fi

    if [[ "$validate_only" == true ]]; then
        # Clean up processed Autounattend.xml
        if [[ -f "$SCRIPT_DIR/http/Autounattend.processed.xml" ]]; then
            rm -f "$SCRIPT_DIR/http/Autounattend.processed.xml"
        fi
        log_success "Validation complete"
        exit 0
    fi
    
    # Build VM
    build_vm "$vars_file" "$log_level"
    
    # Clean up processed Autounattend.xml
    if [[ -f "$SCRIPT_DIR/http/Autounattend.processed.xml" ]]; then
        log_info "Cleaning up processed Autounattend.xml..."
        rm -f "$SCRIPT_DIR/http/Autounattend.processed.xml"
    fi
    
    log_success "Done (ISO mode)"
}

# Run main function (skip when sourced for unit tests, e.g. test-autounattend-processing.sh)
if [[ -z "${AUTOUNATTEND_TEST:-}" ]]; then
    main "$@"
fi
