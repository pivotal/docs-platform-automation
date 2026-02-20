#!/usr/bin/env bash
# Create Windows stemcell from ISO or template using Packer and stembuild
# Supports two modes: build from ISO or clone from template

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Global variables for cleanup
CLEANUP_VM_NAME=""
CLEANUP_PACKER_PID=""
CLEANUP_BUILD_MODE=""
CLEANUP_VARS_FILE=""
CLEANUP_ENABLED=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
# All logging goes to stderr so it doesn't interfere with function return values
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_debug() {
    if [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
    fi
}

# Cleanup function for error handling
cleanup_on_failure() {
    local exit_code=${1:-1}
    
    if [[ "$CLEANUP_ENABLED" != "true" ]]; then
        return 0
    fi
    
    log_warn "=========================================="
    log_warn "Cleanup triggered due to failure"
    log_warn "Exit code: $exit_code"
    log_warn "Build mode: $CLEANUP_BUILD_MODE"
    log_warn "VM name: $CLEANUP_VM_NAME"
    log_warn "=========================================="
    
    # Template mode: Always cleanup (stop and delete VM)
    # ISO mode: Only cleanup on failure
    if [[ "$CLEANUP_BUILD_MODE" == "template" ]]; then
        log_warn "Template mode: Always cleaning up VM (stop and delete)"
    elif [[ "$CLEANUP_BUILD_MODE" != "iso" ]]; then
        log_info "Skipping cleanup (unknown build mode: $CLEANUP_BUILD_MODE)"
        return 0
    fi
    
    # Extract vCenter credentials for cleanup
    if [[ -n "$CLEANUP_VARS_FILE" ]] && [[ -f "$CLEANUP_VARS_FILE" ]]; then
        local vcenter_server=$(grep -E "^vcenter_server\s*=" "$CLEANUP_VARS_FILE" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
        local vcenter_user=$(grep -E "^vcenter_username\s*=" "$CLEANUP_VARS_FILE" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
        local vcenter_pass=$(grep -E "^vcenter_password\s*=" "$CLEANUP_VARS_FILE" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
        local vcenter_insecure=$(grep -E "^vcenter_insecure_connection\s*=" "$CLEANUP_VARS_FILE" | sed 's/#.*$//' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        
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
        kill "$CLEANUP_PACKER_PID" 2>/dev/null || true
        sleep 2
        if kill -0 "$CLEANUP_PACKER_PID" 2>/dev/null; then
            log_warn "Force killing Packer process..."
            kill -9 "$CLEANUP_PACKER_PID" 2>/dev/null || true
        fi
    fi
    
    # Shutdown and delete VM
    if [[ -n "$CLEANUP_VM_NAME" ]]; then
        log_warn "Cleaning up VM: $CLEANUP_VM_NAME"
        
        # Check if VM exists
        if govc vm.info "$CLEANUP_VM_NAME" >/dev/null 2>&1; then
            # Get power state
            local power_state=$(govc vm.info -json "$CLEANUP_VM_NAME" 2>/dev/null | jq -r '.VirtualMachines[0].Runtime.PowerState' 2>/dev/null || echo "unknown")
            
            # Shutdown VM if powered on
            if [[ "$power_state" != "poweredOff" ]]; then
                log_warn "Shutting down VM..."
                govc vm.power -s "$CLEANUP_VM_NAME" >/dev/null 2>&1 || {
                    log_warn "Graceful shutdown failed, forcing power off..."
                    govc vm.power -off "$CLEANUP_VM_NAME" >/dev/null 2>&1 || true
                }
                
                # Wait for shutdown
                local shutdown_timeout=60
                local elapsed=0
                while [[ $elapsed -lt $shutdown_timeout ]]; do
                    sleep 2
                    elapsed=$((elapsed + 2))
                    power_state=$(govc vm.info -json "$CLEANUP_VM_NAME" 2>/dev/null | jq -r '.VirtualMachines[0].Runtime.PowerState' 2>/dev/null || echo "unknown")
                    if [[ "$power_state" == "poweredOff" ]]; then
                        break
                    fi
                done
            fi
            
            # Delete VM
            log_warn "Deleting VM..."
            govc vm.destroy "$CLEANUP_VM_NAME" >/dev/null 2>&1 || {
                log_warn "Failed to delete VM (may require manual cleanup)"
            }
        else
            log_info "VM not found (may have been deleted already)"
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
validate_iso_config() {
    local vars_file="${1:-}"
    local overwrite_flag="${2:-false}"
    
    log_info "Validating ISO configuration..."
    
    if [[ -n "$vars_file" ]] && [[ -f "$vars_file" ]]; then
        # Check if at least one ISO path is configured
        # Extract value, handling quoted strings and stopping at comments
        local iso_local=$(grep -E "^iso_path_local\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        local iso_path=$(grep -E "^iso_path\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        
        # Remove quotes if present (after extracting)
        iso_local=$(echo "$iso_local" | sed 's/^"//;s/"$//')
        iso_path=$(echo "$iso_path" | sed 's/^"//;s/"$//')
        
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
        
        if [[ -z "$iso_local" ]] && [[ -z "$iso_path" ]]; then
            log_error "ISO configuration missing!"
            log_error "You must provide:"
            log_error "  - iso_path (datastore path - ISO already on datastore, or destination for upload)"
            log_error "  - iso_path_local (optional, local file to upload to iso_path destination)"
            exit 1
        fi
        
        # Case 1: Only iso_path_local provided (without iso_path) - ERROR
        if [[ -n "$iso_local" ]] && [[ "$iso_local" != '""' ]] && [[ -z "$iso_path" ]] || [[ "$iso_path" == '""' ]]; then
            log_error "iso_path_local provided but iso_path (destination) is missing!"
            log_error "When uploading a local ISO, you must specify iso_path as the destination"
            log_error "Example: iso_path = \"[datastore1]/ISOs/windows-server-2019.iso\""
            exit 1
        fi
        
        # Case 2: Both iso_path_local and iso_path provided - Upload iso_path_local to iso_path
        if [[ -n "$iso_local" ]] && [[ "$iso_local" != '""' ]] && [[ -n "$iso_path" ]] && [[ "$iso_path" != '""' ]]; then
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
    
    local validate_cmd="packer validate"
    
    if [[ -n "$vars_file" ]]; then
        validate_cmd="$validate_cmd -var-file=$vars_file"
        log_info "Using variables file: $vars_file"
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
    
    # Validate XML syntax
    if ! xmllint --noout "$processed_file" 2>/dev/null; then
        log_error "Processed Autounattend.xml has XML syntax errors!"
        log_error "Please check the template processing"
        return 1
    fi
    
    # Verify replacements - all grep commands must succeed
    if ! grep -q "{{\.Password}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.Username}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.StaticIP}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.SubnetMask}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.SubnetPrefix}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.Gateway}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.DNSServer1}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.DNSServer2_XML}}" "$processed_file" 2>/dev/null && \
       ! grep -q "{{\.WindowsImageName}}" "$processed_file" 2>/dev/null; then
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
    
    # Extract datastore name and file path for verification (ISO mode only)
    if [[ "$build_mode" == "iso" ]]; then
        local iso_datastore=$(echo "${PKR_VAR_iso_path}" | sed 's/^\[\([^]]*\)\].*/\1/')
        local iso_file=$(echo "${PKR_VAR_iso_path}" | sed 's/^\[[^]]*\]\///')
        log_info "ISO Datastore: $iso_datastore"
        log_info "ISO File Path: $iso_file"
        log_info "Full ISO Path: ${PKR_VAR_iso_path}"
    fi
    
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
    
    local vm_name_final="${vm_name_base}-${timestamp}"
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
    
    # Detect build mode before setting up cleanup
    local template_path=$(grep -E "^template_path\s*=" "$vars_file" 2>/dev/null | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//' || echo "")
    local iso_path=$(grep -E "^iso_path\s*=" "$vars_file" 2>/dev/null | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//' || echo "")
    local iso_path_local=$(grep -E "^iso_path_local\s*=" "$vars_file" 2>/dev/null | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//' || echo "")
    
    local build_mode="iso"
    if [[ -n "$template_path" ]] && [[ -z "$iso_path" ]] && [[ -z "$iso_path_local" ]] && [[ -z "${PKR_VAR_iso_path:-}" ]] && [[ -z "${PKR_VAR_iso_path_local:-}" ]]; then
        build_mode="template"
    fi
    
    # Set up cleanup variables and trap for error handling
    CLEANUP_PACKER_PID="$packer_pid"
    CLEANUP_VM_NAME="$vm_name_final"
    CLEANUP_BUILD_MODE="$build_mode"
    CLEANUP_VARS_FILE="$vars_file"
    CLEANUP_ENABLED=true
    
    # Set trap for ERR and EXIT signals
    trap 'cleanup_on_failure $?' ERR
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
        if govc vm.info "$vm_name_final" >/dev/null 2>&1; then
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
        log_error "Last 50 lines of Packer log:"
        tail -50 "$log_file" 2>/dev/null | while IFS= read -r line; do
            log_error "  $line"
        done || log_error "  (Could not read log file)"
        log_error "=========================================="
        # Cleanup will be handled by trap
        exit 1
    fi
    
    # Wait for Windows installation and first boot to complete before starting post-build provisioning
    # Packer boot commands include <wait120> for installation start and <wait60> for first boot
    # But actual installation takes 10-30 minutes, so we need to wait longer
    # We'll wait for the boot sequence to complete before attempting password change
    log_info "Waiting for Windows installation and first boot to complete..."
    log_info "Boot sequence includes: installation (~10-30 min) + first boot (~1-2 min)"
    log_info "Waiting 10 minutes to ensure installation and first boot are complete..."
    log_info "This ensures the password change screen is ready before we attempt to handle it"
    sleep 600  # 10 minutes - allows Windows installation and first boot to complete
    
    # Detect build mode (iso or template)
    # If template_path is provided and no ISO is configured, use template mode
    # Otherwise, use ISO mode (template_path can still be used to create template after stemcell)
    local build_mode="iso"
    local template_path=$(grep -E "^template_path\s*=" "$vars_file" 2>/dev/null | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//' || echo "")
    local iso_path=$(grep -E "^iso_path\s*=" "$vars_file" 2>/dev/null | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//' || echo "")
    local iso_path_local=$(grep -E "^iso_path_local\s*=" "$vars_file" 2>/dev/null | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//' || echo "")
    
    if [[ -n "$template_path" ]] && [[ -z "$iso_path" ]] && [[ -z "$iso_path_local" ]] && [[ -z "${PKR_VAR_iso_path:-}" ]] && [[ -z "${PKR_VAR_iso_path_local:-}" ]]; then
        build_mode="template"
        log_info "Template mode detected: will clone from $template_path"
    else
        build_mode="iso"
        log_info "ISO mode detected: will build from ISO"
        if [[ -n "$template_path" ]] || [[ -n "$(grep -E "^template_name\s*=" "$vars_file" 2>/dev/null)" ]]; then
            log_info "Template will be created after stemcell packaging"
        fi
    fi
    
    # Start post-build provisioning
    log_info "Starting post-build provisioning..."
    post_build_provisioning "$vars_file" "$vm_name_final" "$build_mode" "$log_level"
    local provisioning_exit_code=$?
    
    # Template mode: Always cleanup (stop and delete VM) regardless of success/failure
    if [[ "$build_mode" == "template" ]]; then
        log_info "Template mode: Cleaning up VM (always delete after build)..."
        CLEANUP_ENABLED=true  # Keep cleanup enabled for template mode
        cleanup_on_failure 0  # Force cleanup even on success
        CLEANUP_ENABLED=false
        trap - ERR EXIT
    else
        # ISO mode: Disable cleanup trap on success (VM should be kept as template or stemcell)
        CLEANUP_ENABLED=false
        trap - ERR EXIT
    fi
    
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
        log_error "Check logs in: $SCRIPT_DIR/logs/"
        log_error "Recent log files:"
        ls -t "$SCRIPT_DIR/logs/"*.log 2>/dev/null | head -5 | while IFS= read -r logfile; do
            log_error "  - $logfile"
        done || log_error "  (No log files found)"
        log_error "=========================================="
        # Cleanup will be handled by trap
        exit 1
    fi
}

# Post-build provisioning: configure VM and create stemcell
# Mode: "iso" (full build) or "template" (clone from template)
post_build_provisioning() {
    local vars_file="${1:-}"
    local vm_name="${2:-}"
    local build_mode="${3:-iso}"  # "iso" or "template"
    local log_level="${4:-INFO}"
    
    if [[ -z "$vars_file" ]] || [[ -z "$vm_name" ]]; then
        log_error "post_build_provisioning: Missing required parameters"
        return 1
    fi
    
    log_info "Starting post-build provisioning for VM: $vm_name (mode: $build_mode)"
    
    # Extract variables from vars file
    local vcenter_server=$(grep -E "^vcenter_server\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local vcenter_user=$(grep -E "^vcenter_username\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local vcenter_pass=$(grep -E "^vcenter_password\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local vcenter_insecure=$(grep -E "^vcenter_insecure_connection\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
    local windows_username=$(grep -E "^windows_username\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local windows_password=$(grep -E "^windows_password\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local patch_version=$(grep -E "^patch_version\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local template_path=$(grep -E "^template_path\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local template_name=$(grep -E "^template_name\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    
    # Default username to Administrator if not specified
    if [[ -z "$windows_username" ]]; then
        windows_username="Administrator"
    fi
    
    # Set govc environment
    export GOVC_URL="$vcenter_server"
    export GOVC_USERNAME="$vcenter_user"
    export GOVC_PASSWORD="$vcenter_pass"
    if [[ "$vcenter_insecure" == "true" ]]; then
        export GOVC_INSECURE=true
    fi
    
    # Verify VM exists
    if ! govc vm.info "$vm_name" >/dev/null 2>&1; then
        log_error "VM not found: $vm_name"
        return 1
    fi
    
    local scripts_dir="$SCRIPT_DIR/scripts"
    
    # Step 1: Password change and VMware Tools (ISO mode only)
    if [[ "$build_mode" == "iso" ]]; then
        log_info "Step 1: Handling password change (ISO mode)..."
        sleep 30
        
        local password_change_log="$SCRIPT_DIR/logs/password-change-$(date +%Y%m%d-%H%M%S).log"
        mkdir -p "$(dirname "$password_change_log")"
        "$scripts_dir/handle-password-change-keystrokes.sh" "$vm_name" "$windows_password" "$password_change_log" || {
            log_error "Password change failed"
            return 1
        }
        
        log_info "Step 1.5: Mounting VMware Tools ISO..."
        sleep 10
        local tools_mount_log="$SCRIPT_DIR/logs/vmware-tools-mount-$(date +%Y%m%d-%H%M%S).log"
        mkdir -p "$(dirname "$tools_mount_log")"
        export GOVC_USERNAME="$vcenter_user"
        export GOVC_PASSWORD="$vcenter_pass"
        "$scripts_dir/mount-vmware-tools.sh" "$vm_name" "$tools_mount_log" || {
            log_error "VMware Tools mount failed"
            return 1
        }
        
        log_info "Step 1.6: Installing VMware Tools..."
        local tools_install_log="$SCRIPT_DIR/logs/vmware-tools-install-$(date +%Y%m%d-%H%M%S).log"
        mkdir -p "$(dirname "$tools_install_log")"
        "$scripts_dir/install-vmware-tools-keystrokes.sh" "$vm_name" "$tools_install_log" || {
            log_error "VMware Tools installation failed"
            return 1
        }
        sleep 30
    else
        log_info "Step 1: Skipping password change and VMware Tools (template mode)"
        sleep 10
    fi
    
    # Step 2: Configure network
    log_info "Step 2: Configuring network..."
    
    local static_ip=$(grep -E "^static_ip\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local subnet_mask=$(grep -E "^subnet_mask\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local gateway=$(grep -E "^gateway\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
    local dns_servers=$(grep -E "^dns_servers\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*\[\(.*\)\].*/\1/' | sed 's/"//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
    
    # Export environment variables for PowerShell script
    export STATIC_IP="$static_ip"
    export SUBNET_MASK="$subnet_mask"
    export GATEWAY="$gateway"
    export DNS_SERVERS="$dns_servers"
    export PS_ENV_VARS="STATIC_IP,SUBNET_MASK,GATEWAY,DNS_SERVERS"
    
    local network_log="$SCRIPT_DIR/logs/network-config-$(date +%Y%m%d-%H%M%S).log"
    mkdir -p "$(dirname "$network_log")"
    log_info "Network configuration log: $network_log"
    
    "$scripts_dir/run-powershell-via-govc.sh" "$vm_name" "$scripts_dir/configure-network-manual.ps1" "$windows_username" "$windows_password" "$network_log" || {
        log_error "Network configuration failed - check log: $network_log"
        return 1
    }
    
    # Step 3: Install Windows updates
    log_info "Step 3: Installing Windows updates..."
    local enable_updates=$(grep -E "^enable_windows_updates\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
    
    if [[ "$enable_updates" == "true" ]]; then
        local updates_log="$SCRIPT_DIR/logs/windows-updates-$(date +%Y%m%d-%H%M%S).log"
        mkdir -p "$(dirname "$updates_log")"
        log_info "Windows updates log: $updates_log"
        
        "$scripts_dir/run-windows-updates-loop.sh" "$vm_name" "$windows_username" "$windows_password" 10 > "$updates_log" 2>&1 || {
            log_error "Windows updates installation failed - check log: $updates_log"
            return 1
        }
    else
        log_info "Windows updates disabled (enable_windows_updates=false)"
    fi
    
    # Step 4: Eject CD-ROM
    log_info "Step 4: Ejecting CD-ROM..."
    "$scripts_dir/eject-cdrom.sh" "$vm_name" || {
        log_warn "CD-ROM ejection failed (non-critical)"
    }
    
    # Step 5: Final cleanup
    if [[ -f "$scripts_dir/06-final-cleanup.ps1" ]]; then
        log_info "Step 5: Running final cleanup..."
        local cleanup_log="$SCRIPT_DIR/logs/final-cleanup-$(date +%Y%m%d-%H%M%S).log"
        mkdir -p "$(dirname "$cleanup_log")"
        "$scripts_dir/run-powershell-via-govc.sh" "$vm_name" "$scripts_dir/06-final-cleanup.ps1" "$windows_username" "$windows_password" > "$cleanup_log" 2>&1 || {
            log_error "Final cleanup failed"
            return 1
        }
    fi
    
    # Step 6: Run stembuild construct
    log_info "Step 6: Running stembuild construct..."
    if [[ -z "$patch_version" ]]; then
        log_error "patch_version is required for stembuild"
        return 1
    fi
    
    # Find stembuild binary
    local stembuild_binary=""
    if command -v stembuild &> /dev/null; then
        stembuild_binary=$(command -v stembuild)
    else
        log_error "stembuild not found in PATH"
        return 1
    fi
    
    local construct_log="$SCRIPT_DIR/logs/stembuild-construct-$(date +%Y%m%d-%H%M%S).log"
    mkdir -p "$(dirname "$construct_log")"
    "$scripts_dir/run-stembuild-construct.sh" "$vm_name" "$patch_version" "$stembuild_binary" "$construct_log" || {
        log_error "stembuild construct failed"
        return 1
    }
    
    # Step 7: Run stembuild package
    log_info "Step 7: Running stembuild package..."
    local package_log="$SCRIPT_DIR/logs/stembuild-package-$(date +%Y%m%d-%H%M%S).log"
    mkdir -p "$(dirname "$package_log")"
    
    # Find VM inventory path
    local vm_inventory_path=$(govc find vm -name "$vm_name" 2>/dev/null | head -n1)
    if [[ -z "$vm_inventory_path" ]]; then
        log_error "VM not found: $vm_name"
        return 1
    fi
    
    # Stop VM before packaging (required by stembuild)
    log_info "Stopping VM before packaging..."
    govc vm.power -s "$vm_name" || {
        log_warn "Graceful shutdown failed, forcing power off..."
        govc vm.power -off "$vm_name" || {
            log_error "Failed to power off VM"
            return 1
        }
    }
    
    # Wait for VM to power off
    log_info "Waiting for VM to power off..."
    local shutdown_timeout=300
    local elapsed=0
    while [[ $elapsed -lt $shutdown_timeout ]]; do
        local power_state=$(govc vm.info -json "$vm_name" 2>/dev/null | jq -r '.VirtualMachines[0].Runtime.PowerState' 2>/dev/null || echo "unknown")
        if [[ "$power_state" == "poweredOff" ]]; then
            log_success "VM powered off"
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    if [[ $elapsed -ge $shutdown_timeout ]]; then
        log_error "VM did not power off within timeout"
        return 1
    fi
    
    # Run package
    "$SCRIPT_DIR/package-stemcell.sh" -n "$vm_name" -P "$patch_version" -i "$vm_inventory_path" > "$package_log" 2>&1 || {
        log_error "stembuild package failed"
        return 1
    }
    
    # Find generated stemcell file
    local stemcell_file=$(ls -t bosh-stemcell-*-vsphere-esxi-windows2019-go_agent.tgz 2>/dev/null | head -n1)
    if [[ -n "$stemcell_file" ]]; then
        log_success "Stemcell created: $stemcell_file"
    fi
    
    # Step 8: Create template if template_path or template_name is provided (ISO mode only)
    if [[ "$build_mode" == "iso" ]] && ([[ -n "$template_path" ]] || [[ -n "$template_name" ]]); then
        log_info "Step 8: Creating template from VM..."
        
        # Verify VM is powered off (should be after stembuild package)
        local power_state=$(govc vm.info -json "$vm_name" 2>/dev/null | jq -r '.VirtualMachines[0].Runtime.PowerState' 2>/dev/null || echo "unknown")
        if [[ "$power_state" != "poweredOff" ]]; then
            log_info "VM is not powered off, shutting down..."
            govc vm.power -s "$vm_name" || {
                log_warn "Graceful shutdown failed, forcing power off..."
                govc vm.power -off "$vm_name" || {
                    log_error "Failed to power off VM"
                    return 1
                }
            }
            
            # Wait for VM to power off
            log_info "Waiting for VM to power off..."
            local shutdown_timeout=300
            local elapsed=0
            while [[ $elapsed -lt $shutdown_timeout ]]; do
                sleep 5
                elapsed=$((elapsed + 5))
                power_state=$(govc vm.info -json "$vm_name" 2>/dev/null | jq -r '.VirtualMachines[0].Runtime.PowerState' 2>/dev/null || echo "unknown")
                if [[ "$power_state" == "poweredOff" ]]; then
                    log_success "VM powered off"
                    break
                fi
            done
            
            if [[ $elapsed -ge $shutdown_timeout ]]; then
                log_error "VM did not power off within timeout"
                return 1
            fi
        else
            log_info "VM is already powered off (from stembuild package)"
        fi
        
        # Convert to template
        log_info "Converting VM to template..."
        local final_template_name="${template_name:-${vm_name}-template}"
        govc vm.markastemplate "$vm_name" || {
            log_error "Template conversion failed"
            return 1
        }
        
        # Rename template if custom name provided
        if [[ -n "$template_name" ]] && [[ "$template_name" != "${vm_name}-template" ]]; then
            log_info "Renaming template to: $template_name"
            govc vm.rename -vm "$vm_name" "$template_name" || {
                log_warn "Template rename failed (non-critical)"
            }
            final_template_name="$template_name"
        fi
        
        log_success "Template created: $final_template_name"
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
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
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
    
    # Check prerequisites
    check_prerequisites
    
    # Initialize Packer
    init_packer
    
    if [[ "$init_only" == true ]]; then
        log_success "Initialization complete"
        exit 0
    fi
    
    # Use default variables file if not specified
    if [[ -z "$vars_file" ]] && [[ -f "variables.pkrvars.hcl" ]]; then
        vars_file="variables.pkrvars.hcl"
        log_info "Using default variables file: $vars_file"
    fi
    
    # Process Autounattend.xml template with sed (before Packer runs)
    if ! process_autounattend_template "$vars_file"; then
        log_error "Failed to process Autounattend.xml template"
        exit 1
    fi
    
    # Verify processed file exists and is readable
    local processed_file="$SCRIPT_DIR/http/Autounattend.processed.xml"
    if [[ ! -f "$processed_file" ]]; then
        log_error "Processed Autounattend.xml file not found: $processed_file"
        log_error "Template processing may have failed"
        exit 1
    fi
    if [[ ! -r "$processed_file" ]]; then
        log_error "Processed Autounattend.xml file is not readable: $processed_file"
        exit 1
    fi
    log_info "Verified processed Autounattend.xml exists: $processed_file"
    
    # Set up proxy environment variables BEFORE any govc operations
    # This must be done before validate_iso_config which uses govc for ISO upload/verification
    setup_proxy_environment "$vars_file"
    
    # Verify proxy is set (for debugging)
    if [[ -n "${HTTPS_PROXY:-}" ]]; then
        log_info "Proxy will be used for govc operations"
        log_debug "HTTPS_PROXY=${HTTPS_PROXY}"
    else
        log_info "No proxy configured - direct connection to vCenter"
    fi
    
    # Validate and upload ISO if needed
    # This will upload local ISO to datastore and set PKR_VAR_iso_path
    validate_iso_config "$vars_file" "$overwrite_iso"
    
    # Validate Packer configuration
    validate_packer "$vars_file"
    
    # Extract VM name and vCenter credentials for pre-boot VMware Tools mounting
    # Generate full VM name with timestamp (same format as Packer uses)
    if [[ -n "$vars_file" ]] && [[ -f "$vars_file" ]]; then
        local vm_name_base=$(grep -E "^vm_name\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
        local vcenter_server=$(grep -E "^vcenter_server\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
        local vcenter_user=$(grep -E "^vcenter_username\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
        local vcenter_pass=$(grep -E "^vcenter_password\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1 | sed 's/^"//;s/"$//')
        local vcenter_insecure=$(grep -E "^vcenter_insecure_connection\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        
        if [[ -n "$vm_name_base" ]] && [[ -n "$vcenter_server" ]]; then
            # Generate timestamp in same format as Packer: regex_replace(timestamp(), "[- TZ:]", "")
            # This removes dashes, spaces, T, Z, and colons from ISO 8601 timestamp
            # We generate it once here and pass it to Packer to ensure consistency
            local timestamp=$(date -u +"%Y%m%d%H%M%S" 2>/dev/null || date +"%Y%m%d%H%M%S" 2>/dev/null || echo "")
            local vm_name_final="${vm_name_base}-${timestamp}"
            
            # Export timestamp to Packer so it uses the same value
            export PKR_VAR_build_timestamp="$timestamp"
            log_info "Generated build timestamp: $timestamp"
            log_info "Passing timestamp to Packer via PKR_VAR_build_timestamp"
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
    
    log_success "All done!"
}

# Run main function
main "$@"
