#!/usr/bin/env bash
# Main build script for Windows VM using Packer
# This script orchestrates the Packer build process with verbose logging

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

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
    
    if packer init windows-vm.pkr.hcl; then
        log_success "Packer plugins initialized"
    else
        log_error "Failed to initialize Packer plugins"
        exit 1
    fi
}

# Upload local ISO to datastore
upload_iso_to_datastore() {
    local vars_file="${1:-}"
    local iso_local="${2:-}"
    local resolved_iso_path="${3:-}"
    local force_upload="${4:-false}"  # New parameter: force re-upload even if exists
    
    # All logging functions now go to stderr, so only the path will be returned to stdout
    log_info "=========================================="
    log_info "ISO Upload Process Starting"
    log_info "=========================================="
    log_info "Local ISO file: $resolved_iso_path"
    
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
        local datastore_path="ISOs/$iso_filename"
        local iso_size=$(du -h "$resolved_iso_path" | cut -f1)
        
        log_info "ISO Filename: $iso_filename"
        log_info "ISO Size: $iso_size"
        log_info "Target Datastore Path: [$datastore]/$datastore_path"
        
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
            log_info "Checking for: [$datastore]/ISOs/$iso_filename"
            
            # Get local file size for comparison
            local local_iso_size_bytes=$(stat -f%z "$resolved_iso_path" 2>/dev/null || stat -c%s "$resolved_iso_path" 2>/dev/null || echo "0")
            
            # Check if file exists on datastore
            if govc datastore.ls -ds "$datastore" "ISOs/$iso_filename" >/dev/null 2>&1; then
            log_success "ISO file found on datastore: [$datastore]/ISOs/$iso_filename"
            
            # Try to get file size from datastore for comparison
            log_info "Verifying ISO file details..."
            local datastore_file_info=$(govc datastore.ls -ds "$datastore" -l "ISOs/$iso_filename" 2>/dev/null || echo "")
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
                local return_path="[$datastore]/$datastore_path"
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
            log_info "Target: [$datastore]/ISOs/$iso_filename"
            
            # Delete existing ISO if it exists (to ensure clean upload)
            if govc datastore.ls -ds "$datastore" "ISOs/$iso_filename" >/dev/null 2>&1; then
                log_info "Deleting existing ISO on datastore..."
                if govc datastore.rm -ds "$datastore" "ISOs/$iso_filename" 2>/dev/null; then
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
            if govc datastore.ls -ds "$datastore" "ISOs/$iso_filename" >/dev/null 2>&1; then
                log_success "ISO verification successful"
                # Return datastore path in correct format: [datastore]/path/to/file.iso
                # Ensure path is properly formatted
                if [[ -z "$datastore" ]] || [[ -z "$datastore_path" ]]; then
                    log_error "Cannot construct datastore path - datastore or path is empty"
                    log_error "Datastore: '$datastore'"
                    log_error "Datastore path: '$datastore_path'"
                    exit 1
                fi
                local return_path="[$datastore]/$datastore_path"
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
    
    log_info "Validating ISO configuration..."
    
    if [[ -n "$vars_file" ]] && [[ -f "$vars_file" ]]; then
        # Check if at least one ISO path is configured
        # Extract value, handling quoted strings and stopping at comments
        local iso_local=$(grep -E "^iso_path_local\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        local iso_path=$(grep -E "^iso_path\s*=" "$vars_file" | sed 's/#.*$//' | sed 's/.*=\s*"\([^"]*\)".*/\1/' | sed 's/.*=\s*\([^#]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -1)
        
        # Remove quotes if present (after extracting)
        iso_local=$(echo "$iso_local" | sed 's/^"//;s/"$//')
        iso_path=$(echo "$iso_path" | sed 's/^"//;s/"$//')
        
        if [[ -z "$iso_local" ]] && [[ -z "$iso_path" ]]; then
            log_error "ISO configuration missing!"
            log_error "You must provide either:"
            log_error "  - iso_path_local (local file path - will be uploaded to datastore)"
            log_error "  - iso_path (datastore path - ISO already on datastore)"
            exit 1
        fi
        
        # Validate local ISO file exists if iso_path_local is set
        if [[ -n "$iso_local" ]] && [[ "$iso_local" != '""' ]]; then
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
            
                # Upload ISO to datastore and get datastore path
                log_info "Calling upload_iso_to_datastore function..."
                local datastore_iso_path
                # Force upload if custom ISO was created
                local force_upload_flag="${FORCE_ISO_UPLOAD:-false}"
                datastore_iso_path=$(upload_iso_to_datastore "$vars_file" "$iso_local" "$resolved_iso_path" "$force_upload_flag")
                local upload_exit_code=$?
            
            if [[ $upload_exit_code -ne 0 ]]; then
                log_error "ISO upload function failed with exit code: $upload_exit_code"
                exit 1
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
            
            # Verify file exists on datastore before proceeding
            log_info "Verifying uploaded ISO exists on datastore..."
            local datastore_name=$(echo "$datastore_iso_path" | sed 's/^\[\([^]]*\)\].*/\1/')
            local iso_file_path=$(echo "$datastore_iso_path" | sed 's/^\[[^]]*\]\///')
            
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
                
                # Show actual file listing to confirm
                log_info "File listing from datastore:"
                govc datastore.ls -ds "$datastore_name" "$iso_file_path" 2>&1 | while IFS= read -r line; do
                    log_info "  $line"
                done
            else
                log_error "ISO verification failed - file not found at: $datastore_iso_path"
                log_error "Datastore: $datastore_name"
                log_error "File path: $iso_file_path"
                log_error "Listing contents of ISOs folder:"
                govc datastore.ls -ds "$datastore_name" "ISOs" 2>&1 | while IFS= read -r line; do
                    log_error "  $line"
                done
                exit 1
            fi
            
            # Set environment variable for Packer (Packer will read PKR_VAR_iso_path)
            # Packer automatically reads PKR_VAR_<variable_name> and sets var.<variable_name>
            # Ensure path is clean (no trailing newlines or spaces)
            datastore_iso_path=$(echo "$datastore_iso_path" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            export PKR_VAR_iso_path="$datastore_iso_path"
            
            log_info "=========================================="
            log_success "ISO path configured for Packer"
            log_info "Datastore path: '$datastore_iso_path'"
            log_info "Path length: ${#datastore_iso_path} characters"
            log_info "Environment variable: PKR_VAR_iso_path='$datastore_iso_path'"
            log_info "Path format: [datastore-name]/path/to/file.iso"
            log_info "Packer will use this path automatically"
            log_info "=========================================="
            
            # Double-check the path format one more time
            if [[ "$datastore_iso_path" =~ ^\[([^]]+)\](/.+)$ ]]; then
                log_debug "Path format validation: OK"
                log_debug "  Datastore: '${BASH_REMATCH[1]}'"
                log_debug "  File path: '${BASH_REMATCH[2]}'"
            else
                log_error "Path format validation failed!"
                log_error "Path does not match expected format: [datastore]/path/to/file.iso"
                log_error "Actual path: '$datastore_iso_path'"
                log_error "Path hex: $(echo -n "$datastore_iso_path" | xxd -p | head -1)"
                exit 1
            fi
        elif [[ -n "$iso_path" ]] && [[ "$iso_path" != '""' ]]; then
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
            
            log_info "Using datastore ISO path: $iso_path"
            log_info "Ensure ISO is already uploaded to vSphere datastore"
            
            # Set environment variable for Packer
            export PKR_VAR_iso_path="$iso_path"
            log_info "Environment variable: PKR_VAR_iso_path='$iso_path'"
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
    
    # Source template file
    local template_file="http/Autounattend.xml"
    local processed_file="http/Autounattend.processed.xml"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "Template file not found: $template_file"
        return 1
    fi
    
    # Escape special characters for sed
    local escaped_username=$(echo "$username" | sed 's/[[\.*^$()+?{|]/\\&/g')
    local escaped_password=$(echo "$password" | sed 's/[[\.*^$()+?{|]/\\&/g')
    local escaped_static_ip=$(echo "$static_ip" | sed 's/[[\.*^$()+?{|]/\\&/g')
    local escaped_subnet_mask=$(echo "$subnet_mask" | sed 's/[[\.*^$()+?{|]/\\&/g')
    local escaped_subnet_prefix=$(echo "$subnet_prefix" | sed 's/[[\.*^$()+?{|]/\\&/g')
    local escaped_gateway=$(echo "$gateway" | sed 's/[[\.*^$()+?{|]/\\&/g')
    local escaped_dns_servers=$(echo "$dns_servers" | sed 's/[[\.*^$()+?{|]/\\&/g')
    local escaped_dns_server1=$(echo "$dns_server1" | sed 's/[[\.*^$()+?{|]/\\&/g')
    local escaped_dns_server2=$(echo "$dns_server2" | sed 's/[[\.*^$()+?{|]/\\&/g' 2>/dev/null || echo "")
    
    # Generate XML for optional DNSServer2
    # If DNSServer2 is provided, include it; otherwise leave placeholder empty (will be removed)
    local dns_server2_xml=""
    if [[ -n "$dns_server2" ]] && [[ "$dns_server2" != "" ]]; then
        dns_server2_xml="                        <IpAddress wcm:action=\"add\" wcm:keyValue=\"2\">$dns_server2</IpAddress>"
    fi
    
    # Replace template variables with actual values
    # Use '|' as sed delimiter to avoid conflicts with XML characters like '/' and '<'
    # First, replace all variables except DNSServer2_XML
    local temp_file=$(mktemp)
    sed -e "s|{{\.Username}}|$escaped_username|g" \
        -e "s|{{\.Password}}|$escaped_password|g" \
        -e "s|{{\.StaticIP}}|$escaped_static_ip|g" \
        -e "s|{{\.SubnetMask}}|$escaped_subnet_mask|g" \
        -e "s|{{\.SubnetPrefix}}|$escaped_subnet_prefix|g" \
        -e "s|{{\.Gateway}}|$escaped_gateway|g" \
        -e "s|{{\.DNSServer1}}|$escaped_dns_server1|g" \
        "$template_file" > "$temp_file"
    
    # Handle DNSServer2_XML separately - if empty, remove the placeholder line entirely
    if [[ -n "$dns_server2_xml" ]]; then
        # DNSServer2 is provided - replace placeholder with XML
        # Use awk to handle the replacement more safely (avoids sed escaping issues)
        awk -v replacement="$dns_server2_xml" '{gsub(/\{\{\.DNSServer2_XML\}\}/, replacement); print}' "$temp_file" > "$processed_file"
    else
        # DNSServer2 is not provided - remove the placeholder line entirely
        sed "/{{\.DNSServer2_XML}}/d" "$temp_file" > "$processed_file"
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
    
    # Verify replacements
    if grep -q "{{\.Password}}" "$processed_file" || grep -q "{{\.Username}}" "$processed_file" || \
       grep -q "{{\.StaticIP}}" "$processed_file" || grep -q "{{\.SubnetMask}}" "$processed_file" || \
       grep -q "{{\.SubnetPrefix}}" "$processed_file" || grep -q "{{\.Gateway}}" "$processed_file" || \
       grep -q "{{\.DNSServer1}}" "$processed_file" || grep -q "{{\.DNSServer2_XML}}" "$processed_file"; then
        log_error "Template variables were not replaced!"
        log_error "Check that Autounattend.xml uses correct template variables"
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
    
    # Set up proxy environment variables if proxy is configured
    # Packer vsphere-iso builder uses these environment variables
    # IMPORTANT: This must be done BEFORE running packer commands
    setup_proxy_environment "$vars_file"
    
    # Verify proxy is set (for debugging)
    if [[ -n "${HTTPS_PROXY:-}" ]]; then
        log_info "Proxy will be used for Packer connections"
        log_debug "HTTPS_PROXY=${HTTPS_PROXY}"
    else
        log_info "No proxy configured - direct connection to vCenter"
    fi
    
    # Build command
    # Note: PKR_VAR_iso_path may be set by validate_iso_config if iso_path_local was used
    # Packer automatically reads PKR_VAR_* environment variables
    local build_cmd="packer build"
    
    # Log environment variables that will be used
    if [[ -n "${PKR_VAR_iso_path:-}" ]]; then
        log_info "Using ISO path from environment: ${PKR_VAR_iso_path}"
    fi
    
    # Add variables file if provided
    if [[ -n "$vars_file" ]]; then
        build_cmd="$build_cmd -var-file=$vars_file"
    fi
    
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
    
    # Run Packer build and capture output to log file
    if eval "$build_cmd" 2>&1 | tee "$log_file"; then
        local build_end=$(date +%s)
        local build_duration=$((build_end - build_start))
        local build_minutes=$((build_duration / 60))
        
        log_success "Build completed successfully in ${build_minutes} minutes"
        
        # Display manifest if available
        if [[ -f "logs/manifest.json" ]]; then
            log_info "Build manifest:"
            if command -v jq &> /dev/null; then
                jq -r '.builds[] | "  VM: \(.name) | Template: \(.artifact_id)"' logs/manifest.json
            else
                cat logs/manifest.json
            fi
        fi
        
    else
        log_error "Build failed"
        exit 1
    fi
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
    echo "  Windows VM Build Script (Packer)"
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
    
    # Validate and upload ISO if needed
    # This will upload local ISO to datastore and set PKR_VAR_iso_path
    validate_iso_config "$vars_file"
    
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
            
            # Background VMware Tools mount - DISABLED
            # Mounting Tools during installation can interfere with disk selection
            # "partition selected does not meet requirements" error may be caused by Tools ISO mount
            # Strategy: Mount Tools ONLY via provisioner after installation completes and WinRM is available
            # This ensures clean installation without interference
            log_info "Background VMware Tools mount is DISABLED"
            log_info "Reason: Mounting Tools during installation can interfere with disk selection"
            log_info "VMware Tools will be mounted via provisioner after installation completes"
            log_info "Provisioner in windows-vm.pkr.hcl will mount Tools after WinRM connects"
        fi
    fi
    
    if [[ "$validate_only" == true ]]; then
        # Clean up processed Autounattend.xml
        if [[ -f "http/Autounattend.processed.xml" ]]; then
            rm -f "http/Autounattend.processed.xml"
        fi
        log_success "Validation complete"
        exit 0
    fi
    
    # Build VM
    build_vm "$vars_file" "$log_level"
    
    # Clean up processed Autounattend.xml
    if [[ -f "http/Autounattend.processed.xml" ]]; then
        log_info "Cleaning up processed Autounattend.xml..."
        rm -f "http/Autounattend.processed.xml"
    fi
    
    log_success "All done!"
}

# Run main function
main "$@"
