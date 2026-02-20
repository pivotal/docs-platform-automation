#!/usr/bin/env bash
# Package BOSH stemcell from Windows VM template
# Based on: https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/elastic-application-runtime/6-0/eart/create-vsphere-stemcell-automatically.html
# This script automates Step 5: Packaging the BOSH stemcell

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Package a BOSH stemcell from a Windows VM template using stembuild.

Required Options:
  -v, --vcenter-url URL              vCenter Server URL
  -u, --vcenter-username USERNAME   vCenter username
  -p, --vcenter-password PASSWORD   vCenter password
  -n, --vm-name VM_NAME              Name of the VM to package
  -P, --patch-version VERSION        Patch version for the stemcell (e.g., "2019.12.3" or "3")

Optional Options:
  -b, --stembuild-binary PATH        Path to stembuild binary (optional if stembuild is in PATH from binaries image)
  -i, --vm-inventory-path PATH       vCenter inventory path to VM (auto-detected if not provided)
  -c, --vcenter-ca-certs PATH        Path to custom CA certificates file
  -I, --insecure                     Allow insecure vCenter connections (self-signed certs)
  -l, --log-level LEVEL              Logging level: DEBUG, INFO, WARN, ERROR (default: INFO)
  -h, --help                         Show this help message

Environment Variables:
  GOVC_URL                           vCenter URL (alternative to -v)
  GOVC_USERNAME                      vCenter username (alternative to -u)
  GOVC_PASSWORD                      vCenter password (alternative to -p)
  GOVC_INSECURE                      Set to 'true' for insecure connections (alternative to -I)

Examples:
  # Using command line arguments (stembuild from binaries image PATH)
  $0 -v vcenter.example.com \\
     -u administrator@vsphere.local \\
     -p 'MyPassword123!' \\
     -n windows-base-vm-20260218112627 \\
     -P "2019.12.3"

  # Using environment variables (stembuild from binaries image PATH)
  export GOVC_URL=vcenter.example.com
  export GOVC_USERNAME=administrator@vsphere.local
  export GOVC_PASSWORD='MyPassword#123!'
  export GOVC_INSECURE=true
  $0 -n windows-base-vm-20260218112627 \\
     -P "3"

  # Using custom stembuild binary path (if not in binaries image)
  $0 -v vcenter.example.com \\
     -u administrator@vsphere.local \\
     -p 'MyPassword123!' \\
     -n windows-base-vm-20260218112627 \\
     -P "2019.12.3" \\
     -b ./stembuild-windows-2019-2

EOF
    exit 1
}

# Parse command line arguments
VCENTER_URL=""
VCENTER_USERNAME=""
VCENTER_PASSWORD=""
VM_NAME=""
PATCH_VERSION=""
STEMBUILD_BINARY=""
VM_INVENTORY_PATH=""
VCENTER_CA_CERTS=""
VCENTER_INSECURE="false"
LOG_LEVEL="INFO"

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--vcenter-url)
            VCENTER_URL="$2"
            shift 2
            ;;
        -u|--vcenter-username)
            VCENTER_USERNAME="$2"
            shift 2
            ;;
        -p|--vcenter-password)
            VCENTER_PASSWORD="$2"
            shift 2
            ;;
        -n|--vm-name)
            VM_NAME="$2"
            shift 2
            ;;
        -P|--patch-version)
            PATCH_VERSION="$2"
            shift 2
            ;;
        -b|--stembuild-binary)
            STEMBUILD_BINARY="$2"
            shift 2
            ;;
        -i|--vm-inventory-path)
            VM_INVENTORY_PATH="$2"
            shift 2
            ;;
        -c|--vcenter-ca-certs)
            VCENTER_CA_CERTS="$2"
            shift 2
            ;;
        -I|--insecure)
            VCENTER_INSECURE="true"
            shift
            ;;
        -l|--log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for govc
    if ! command -v govc &> /dev/null; then
        missing_tools+=("govc")
    else
        local govc_version=$(govc version 2>/dev/null | head -n1 || echo "unknown")
        log_info "Found: $govc_version"
    fi
    
    # Check for stembuild binary
    # First check if it's in PATH (from binaries image)
    if command -v stembuild &> /dev/null; then
        local stembuild_path=$(command -v stembuild)
        log_info "Found stembuild in PATH: $stembuild_path"
        STEMBUILD_BINARY="$stembuild_path"
    elif [[ -n "$STEMBUILD_BINARY" ]]; then
        # Use provided path if specified
        if [[ ! -f "$STEMBUILD_BINARY" ]]; then
            log_error "stembuild binary not found: $STEMBUILD_BINARY"
            exit 1
        fi
        if [[ ! -x "$STEMBUILD_BINARY" ]]; then
            log_warn "stembuild binary is not executable, attempting to make it executable..."
            chmod +x "$STEMBUILD_BINARY" || {
                log_error "Failed to make stembuild binary executable"
                exit 1
            }
        fi
        log_info "Using provided stembuild binary: $STEMBUILD_BINARY"
    else
        log_error "stembuild binary not found in PATH and no path provided"
        log_error "Either ensure stembuild is in PATH (from binaries image) or use -b/--stembuild-binary"
        exit 1
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Get vCenter credentials from environment or arguments
setup_vcenter_creds() {
    # Use environment variables if provided, otherwise use command line arguments
    export GOVC_URL="${GOVC_URL:-$VCENTER_URL}"
    export GOVC_USERNAME="${GOVC_USERNAME:-$VCENTER_USERNAME}"
    export GOVC_PASSWORD="${GOVC_PASSWORD:-$VCENTER_PASSWORD}"
    
    if [[ "$VCENTER_INSECURE" == "true" ]] || [[ "${GOVC_INSECURE:-}" == "true" ]]; then
        export GOVC_INSECURE=true
    fi
    
    if [[ -z "$GOVC_URL" ]] || [[ -z "$GOVC_USERNAME" ]] || [[ -z "$GOVC_PASSWORD" ]]; then
        log_error "vCenter credentials are required"
        log_error "Provide via command line (-v, -u, -p) or environment variables (GOVC_URL, GOVC_USERNAME, GOVC_PASSWORD)"
        exit 1
    fi
    
    log_info "vCenter URL: $GOVC_URL"
    log_info "vCenter Username: $GOVC_USERNAME"
    log_info "vCenter Insecure: ${GOVC_INSECURE:-false}"
}

# Find VM inventory path
find_vm_inventory_path() {
    log_info "Finding VM inventory path for: $VM_NAME"
    
    if [[ -n "$VM_INVENTORY_PATH" ]]; then
        log_info "Using provided inventory path: $VM_INVENTORY_PATH"
        return 0
    fi
    
    # Use govc to find the VM
    local vm_path=$(govc find vm -name "$VM_NAME" 2>/dev/null | head -n1)
    
    if [[ -z "$vm_path" ]]; then
        log_error "VM not found: $VM_NAME"
        log_error "Available VMs:"
        govc ls / -t VirtualMachine 2>/dev/null | head -10 || echo "Could not list VMs"
        exit 1
    fi
    
    VM_INVENTORY_PATH="$vm_path"
    log_success "Found VM inventory path: $VM_INVENTORY_PATH"
}

# Stop the VM
stop_vm() {
    log_info "Stopping VM: $VM_NAME"
    
    # Check current power state
    local power_state=$(govc vm.info -json "$VM_NAME" 2>/dev/null | jq -r '.VirtualMachines[0].Runtime.PowerState' 2>/dev/null || echo "unknown")
    log_info "Current VM power state: $power_state"
    
    if [[ "$power_state" == "poweredOff" ]]; then
        log_info "VM is already powered off"
        return 0
    fi
    
    # Gracefully shutdown the VM
    log_info "Attempting graceful shutdown..."
    govc vm.power -s "$VM_NAME" || {
        log_warn "Graceful shutdown failed, forcing power off..."
        govc vm.power -off "$VM_NAME" || {
            log_error "Failed to power off VM"
            exit 1
        }
    }
    
    # Wait for VM to power off
    log_info "Waiting for VM to power off..."
    local timeout=300  # 5 minutes
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        sleep 5
        elapsed=$((elapsed + 5))
        power_state=$(govc vm.info -json "$VM_NAME" 2>/dev/null | jq -r '.VirtualMachines[0].Runtime.PowerState' 2>/dev/null || echo "unknown")
        if [[ "$power_state" == "poweredOff" ]]; then
            log_success "VM powered off successfully"
            return 0
        fi
        if [[ $((elapsed % 30)) -eq 0 ]]; then
            log_info "Still waiting for VM to power off... (${elapsed}s elapsed)"
        fi
    done
    
    log_error "VM did not power off within ${timeout}s timeout"
    exit 1
}

# Package the stemcell using stembuild
package_stemcell() {
    log_info "Packaging BOSH stemcell..."
    log_info "VM Name: $VM_NAME"
    log_info "VM Inventory Path: $VM_INVENTORY_PATH"
    log_info "Patch Version: $PATCH_VERSION"
    log_info "Stembuild Binary: $STEMBUILD_BINARY"
    
    # Build stembuild package command
    # According to the documentation, we need to handle special characters in passwords
    # by using environment variables GOVC_USERNAME and GOVC_PASSWORD
    
    local package_cmd="$STEMBUILD_BINARY package"
    package_cmd="$package_cmd -vcenter-url \"$GOVC_URL\""
    package_cmd="$package_cmd -vcenter-username \"$GOVC_USERNAME\""
    package_cmd="$package_cmd -vcenter-password \"$GOVC_PASSWORD\""
    package_cmd="$package_cmd -patch-version \"$PATCH_VERSION\""
    package_cmd="$package_cmd -vm-inventory-path \"$VM_INVENTORY_PATH\""
    
    if [[ -n "$VCENTER_CA_CERTS" ]]; then
        if [[ ! -f "$VCENTER_CA_CERTS" ]]; then
            log_error "CA certificates file not found: $VCENTER_CA_CERTS"
            exit 1
        fi
        package_cmd="$package_cmd -vcenter-ca-certs \"$VCENTER_CA_CERTS\""
        log_info "Using custom CA certificates: $VCENTER_CA_CERTS"
    fi
    
    log_info "Running stembuild package command..."
    log_info "This may take up to 30 minutes to complete..."
    
    # Execute the command
    # Note: The documentation recommends using environment variables for passwords with special characters
    # We've already set GOVC_USERNAME and GOVC_PASSWORD above
    eval "$package_cmd"
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "stembuild package failed with exit code: $exit_code"
        log_error "Check the error messages above for details"
        exit $exit_code
    fi
    
    log_success "Stemcell packaging completed successfully"
    
    # Find the generated stemcell file
    # stembuild creates stemcell files in the current directory
    # Format: bosh-stemcell-*-vsphere-esxi-windows2019-go_agent.tgz
    local stemcell_file=$(ls -t bosh-stemcell-*-vsphere-esxi-windows2019-go_agent.tgz 2>/dev/null | head -n1)
    
    if [[ -n "$stemcell_file" ]]; then
        log_success "Stemcell file created: $stemcell_file"
        log_info "File location: $(pwd)/$stemcell_file"
        log_info "File size: $(du -h "$stemcell_file" | cut -f1)"
    else
        log_warn "Could not find generated stemcell file"
        log_warn "Please check the current directory for stemcell files"
    fi
}

# Main function
main() {
    log_info "=========================================="
    log_info "BOSH Stemcell Packaging Script"
    log_info "=========================================="
    log_info ""
    
    # Validate required parameters
    if [[ -z "$VM_NAME" ]]; then
        log_error "VM name is required (use -n or --vm-name)"
        usage
    fi
    
    if [[ -z "$PATCH_VERSION" ]]; then
        log_error "Patch version is required (use -P or --patch-version)"
        usage
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Setup vCenter credentials
    setup_vcenter_creds
    
    # Find VM inventory path
    find_vm_inventory_path
    
    # Stop the VM (required before packaging)
    stop_vm
    
    # Package the stemcell
    package_stemcell
    
    log_success "=========================================="
    log_success "Stemcell packaging completed successfully"
    log_success "=========================================="
}

# Run main function
main "$@"
