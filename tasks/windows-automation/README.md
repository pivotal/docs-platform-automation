# Windows VM Automation

Automated Windows Server 2019 VM creation and BOSH stemcell packaging for vSphere using Packer and stembuild.

## Supported Commands

### Build from ISO

Creates a new VM from a Windows Server 2019 ISO, installs Windows, configures network, installs updates, and creates a stemcell.

```bash
./build.sh -f variables.pkrvars.hcl
```

### Build from Template

Clones an existing template VM, configures network, installs updates, and creates a stemcell. Skips password change and VMware Tools installation.

```bash
./build.sh -f variables.pkrvars.hcl
```

**Note:** Template mode is automatically detected when `template_path` is set and no ISO paths are configured.

## Variables File Format

The variables file (`variables.pkrvars.hcl`) contains all configuration for the build process. It can be created manually or generated from Concourse task inputs.

### Required Variables

```hcl
# vCenter Configuration (MANDATORY)
vcenter_server              = "vcenter.example.com"
vcenter_username            = "administrator@vsphere.local"
vcenter_password            = "YourPassword"
vcenter_insecure_connection = true  # or false

# vSphere Infrastructure (MANDATORY)
vcenter_datacenter    = "Datacenter"
vcenter_cluster       = "Cluster"  # or leave empty if using host
vcenter_host          = ""         # or "esxi-host.example.com" if using host
vcenter_datastore     = "datastore1"
vcenter_network       = "VM Network"

# VM Configuration (OPTIONAL - defaults shown, can be overridden)
vm_name         = "windows-base-vm"  # Default: "windows-base-vm"
vm_cpu_count    = 8                  # Default: 8
vm_memory_mb    = 16384              # Default: 16384 (16 GB)
vm_disk_size_gb = 100                # Default: 100

# Network Configuration (MANDATORY)
static_ip    = "192.168.1.100"
subnet_mask  = "255.255.255.0"
gateway      = "192.168.1.1"
dns_servers  = ["8.8.8.8", "8.8.4.4"]

# Windows Configuration (MANDATORY)
windows_username = "Administrator"  # Default: "Administrator"
windows_password = "YourPassword"

# Stemcell Configuration (MANDATORY)
patch_version = "2019.12.3"  # or "3"
```

### ISO Mode Variables

For building from ISO, set one of:

```hcl
# Option 1: Datastore path (ISO already uploaded to vSphere)
iso_path = "[datastore1]/ISOs/windows-server-2019.iso"

# Option 2: Local ISO path (will be uploaded automatically)
iso_path_local = "/path/to/windows-server-2019.iso"
```

### Template Mode Variables

For building from template, set:

```hcl
# Template path in vCenter inventory
template_path = "/Datacenter/vm/Templates/windows-2019-template"
```

**Note:** When `template_path` is set and no ISO paths are configured, template mode is automatically used.

### Optional Variables

```hcl
# Proxy Configuration (optional - if needed)
http_proxy     = "http://proxy.example.com:8080"
https_proxy    = "http://proxy.example.com:8080"
no_proxy       = "localhost,127.0.0.1"

# vSphere Location (optional)
vcenter_folder        = "/Datacenter/vm/WindowsVMs"
vcenter_resource_pool = "ResourcePool"

# Template Name (optional - for final template after stemcell)
template_name = "my-windows-template"

# Build Options (optional - defaults shown)
enable_windows_updates = true  # Default: true
log_level              = "INFO"  # Default: "INFO" (options: DEBUG, INFO, WARN, ERROR)
```

## Example Variables File

See `variables.pkrvars.hcl.example` for a complete example with all available options.

## Build Process

1. **ISO Mode:**
   - Uploads ISO to datastore (if `iso_path_local` is used)
   - Creates VM from ISO
   - Installs Windows Server 2019
   - Handles password change
   - Installs VMware Tools
   - Configures network (static IP and DNS)
   - Installs Windows updates
   - Runs `stembuild construct`
   - Runs `stembuild package` (creates stemcell)
   - Optionally creates template (if `template_path` or `template_name` is set)

2. **Template Mode:**
   - Clones VM from template
   - Configures network (static IP and DNS)
   - Installs Windows updates
   - Runs `stembuild construct`
   - Runs `stembuild package` (creates stemcell)
   - **Always deletes VM after completion** (success or failure)

## Output

- **Stemcell file:** `bosh-stemcell-*-vsphere-esxi-windows2019-go_agent.tgz`
- **Logs:** `logs/` directory with detailed logs for each step
- **Template:** Created in vCenter (ISO mode only, if configured)

## Requirements

- Packer 1.7.0+
- govc (VMware vSphere CLI)
- stembuild binary
- Access to vCenter with appropriate permissions
- Windows Server 2019 ISO (for ISO mode) or existing template (for template mode)
