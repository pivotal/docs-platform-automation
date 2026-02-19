# Example variables file for Windows VM build
# Copy this file to variables.pkrvars.hcl and fill in your values
# Or use environment variables with PKR_VAR_ prefix

# vCenter Configuration
vcenter_server              = "vcenter.tanzu.lab"
vcenter_username            = "administrator@vsphere.local"
vcenter_password            = "VMware1!"
vcenter_insecure_connection = true

# Proxy Configuration (Optional - for accessing vCenter through HTTP/HTTPS proxy)
# If your environment requires a proxy to access vCenter, configure these:
http_proxy     = "http://10.144.36.64"  
https_proxy    = "http://10.144.36.64"  
no_proxy       = "localhost,127.0.0.1,.local"


# vSphere Infrastructure
vcenter_datacenter    = "tanzu-dc01"
vcenter_cluster       = ""  # Leave empty if using host
vcenter_host          = "esx-01.tanzu.lab"           # Leave empty if using cluster
vcenter_datastore     = "iscsi-storage"
vcenter_network       = "seg_tas-infra"
vcenter_folder        = "/Datacenter/vm/WindowsVMs"  # Optional
vcenter_resource_pool = "rp01_tas"  # Optional

# VM Configuration
vm_name         = "windows-base-vm"  # Temporary VM name during build (will have timestamp appended)
vm_cpu_count    = 8
vm_memory_mb    = 16384  # 16 GB
vm_disk_size_gb = 100

# Template Configuration
# Template name for the final template (after VM is converted)
# If not provided, will be automatically derived from ISO filename
# Example: "windows-server-2019.iso" -> "windows-server-2019-template"
template_name   = "stemcell-automation-base-2019"  # Optional: Custom template name (e.g., "my-windows-template")
                   # If empty, template name will be derived from ISO filename

# ISO Configuration
# REQUIRED: Datastore path to Windows Server 2019 ISO
# Format: [datastore-name]/path/to/file.iso
# Example: [iscsi-storage]/ISOs/windows-server-2019.iso
#
# To upload ISO to datastore first, use the upload-iso.sh helper script:
#   ./upload-iso.sh ./windows-2019.iso iscsi-storage ISOs
iso_path = "[iscsi-storage]/ISOs/windows-2019.iso"

# Option 1: Local ISO path (Packer will upload automatically)
iso_path_local = "/Users/rjanakiraman/docs-platform-automation/windows-2019.iso"

# Windows Configuration
windows_username = "Administrator"
windows_password = "Admin123!"

# Network Configuration (REQUIRED - Step 2 from documentation)
# Network must be configured before Windows updates can be installed
static_ip    = "192.168.122.100"  # REQUIRED: Static IP address
subnet_mask  = "255.255.255.0"  # REQUIRED: Subnet mask
gateway      = "192.168.122.1"    # REQUIRED: Default gateway
dns_servers  = ["192.168.111.155"]  # REQUIRED: DNS servers (at least one)

# VMware Tools Configuration
vmware_tools_mode = "upload"  # "upload" or "attach"
vmware_tools_path = ""        # Required if mode is "attach"

# Build Options
enable_windows_updates = true
log_level              = "INFO"  # DEBUG, INFO, WARN, ERROR
