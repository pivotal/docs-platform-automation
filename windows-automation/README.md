# Windows VM Build with Packer

This directory contains a Packer-based build system for creating Windows Server 2019 VMs for vSphere, following the [VMware Tanzu documentation](https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/elastic-application-runtime/6-0/eart/create-vsphere-stemcell-automatically.html).

## Overview

This build system automates **Steps 1-3** from the VMware Tanzu documentation:

- **Step 1**: Create a Base VM for the BOSH Stemcell
- **Step 2**: Configure the Base VM (network settings and Windows updates)
- **Step 3**: Creates a template ready for cloning

## Architecture

The build process uses Packer to:

1. Create a VM from Windows Server 2019 ISO
2. Perform unattended Windows installation using `Autounattend.xml`
3. Configure network settings (static IP) - **Step 2 from documentation**
4. Mount VMware Tools (per documentation: "Guest OS > Install VMware Tools > Mount")
5. Install VMware Tools (per documentation: run `D:\setup64.exe`)
6. Install all Windows updates - **Step 2 from documentation**
7. Verify OS version
8. Disconnect CD/DVD drive (per documentation)
9. Convert VM to template - **Step 3 from documentation**

## Prerequisites

1. **Packer** (>= 1.7.0)
   ```bash
   packer version
   ```

2. **vSphere Plugin for Packer**
   ```bash
   packer init windows-vm.pkr.hcl
   ```

3. **Windows Server 2019 ISO**
   - Server Core installation
   - Build number: 17763 (or later)
   - Place in `./windows-server-2019.iso` or provide path in variables

4. **vCenter Access**
   - vCenter Server URL
   - Username and password
   - Access to create VMs and templates

5. **govc** (optional, for advanced operations)
   - Used by shell-local provisioners for VMware Tools mounting and template renaming

## Configuration

### 1. Copy Variables File

```bash
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
```

### 2. Edit Variables

Edit `variables.pkrvars.hcl` with your vSphere and Windows configuration:

```hcl
# vCenter Configuration
vcenter_server              = "vcenter.example.com"
vcenter_username            = "administrator@vsphere.local"
vcenter_password            = "YourPassword"
vcenter_insecure_connection = true

# vSphere Infrastructure
vcenter_datacenter    = "Datacenter"
vcenter_cluster       = "Cluster"  # or leave empty if using host
vcenter_host          = "esxi.example.com"  # or leave empty if using cluster
vcenter_datastore     = "datastore1"
vcenter_network       = "VM Network"

# VM Configuration
vm_name         = "windows-base-vm"
vm_cpu_count    = 4
vm_memory_mb    = 8192
vm_disk_size_gb = 100

# Windows Configuration
windows_username = "Administrator"
windows_password = "YourPassword123!"

# Network Configuration (REQUIRED - Step 2 from documentation)
static_ip    = "192.168.1.100"
subnet_mask  = "255.255.255.0"
gateway      = "192.168.1.1"
dns_servers  = ["8.8.8.8", "8.8.4.4"]

# ISO Configuration
iso_path_local = "./windows-server-2019.iso"  # Local path (Packer will upload)
# OR
# iso_path = "[datastore1]/ISOs/windows-server-2019.iso"  # Already in datastore

# Template Configuration
template_name = "windows-server-2019-template"  # Optional
```

### 3. Proxy Configuration (if needed)

If your environment requires a proxy to access vCenter, set environment variables before running Packer:

```bash
export HTTP_PROXY="http://proxy.example.com:80"
export HTTPS_PROXY="http://proxy.example.com:80"
export NO_PROXY="localhost,127.0.0.1,.local"
```

## Usage

### Validate Configuration

```bash
packer validate -var-file=variables.pkrvars.hcl windows-vm.pkr.hcl
```

### Build VM and Template

```bash
packer build -var-file=variables.pkrvars.hcl windows-vm.pkr.hcl
```

### Build with Debug Logging

```bash
PACKER_LOG=1 packer build -var-file=variables.pkrvars.hcl windows-vm.pkr.hcl
```

## Build Process

The build follows the VMware Tanzu documentation steps:

### Step 1: Create Base VM

1. Packer creates VM in vSphere
2. Attaches Windows Server 2019 ISO
3. Boots from ISO
4. Windows Setup runs with `Autounattend.xml` (unattended installation)
5. WinRM is configured during installation
6. Packer connects via WinRM

### Step 1.5: Install VMware Tools

1. Mount VMware Tools ISO (via `govc`)
2. Install VMware Tools by running `D:\setup64.exe` (per documentation)

### Step 2: Configure Base VM

1. **Configure Network** (REQUIRED)
   - Sets static IP address
   - Configures subnet mask, gateway, DNS servers
   - Network must be configured before Windows updates

2. **Install Windows Updates**
   - Downloads and installs all available Windows updates
   - Can take 30-60 minutes depending on update size
   - Requires network connectivity (from previous step)

3. **Verify OS Version**
   - Confirms Windows Server 2019 is installed correctly

### Step 3: Create Template

1. Disconnect CD/DVD drive (per documentation)
2. Convert VM to template
3. Rename template (if custom name provided)

## File Structure

```
windows-automation/
├── windows-vm.pkr.hcl          # Main Packer configuration
├── variables.pkr.hcl            # Variable definitions
├── variables.pkrvars.hcl        # Your variable values (create from .example)
├── http/
│   └── Autounattend.xml         # Windows unattended installation file
└── scripts/
    ├── 01-wait-for-ready.ps1    # Wait for Windows to be ready
    ├── 02-configure-network.ps1  # Configure network (Step 2)
    ├── 03-install-vmware-tools.ps1  # Install VMware Tools
    ├── 04-install-windows-updates.ps1  # Install Windows updates (Step 2)
    ├── 06-final-cleanup.ps1    # Final cleanup
    ├── mount-vmware-tools.sh    # Mount VMware Tools ISO
    ├── eject-cdrom.sh           # Disconnect CD/DVD drive
    └── rename-template.sh       # Rename template
```

## Troubleshooting

### Autounattend.xml Not Detected

If Windows Setup shows the language selection screen, `Autounattend.xml` is not being detected:

1. Check Packer logs for HTTP server startup
2. Verify `http/Autounattend.xml` exists
3. Check VM console in vSphere to see if Windows Setup is running
4. Verify network connectivity (Windows Setup needs network to download from HTTP server)

### WinRM Connection Fails

If Packer cannot connect via WinRM:

1. Check Windows firewall rules (WinRM port 5985 should be open)
2. Verify network connectivity (VM needs IP address)
3. Check WinRM is enabled (configured in `Autounattend.xml`)
4. Increase `winrm_timeout` in `windows-vm.pkr.hcl` if needed

### Network Configuration Fails

If network configuration fails:

1. Verify static IP is not already in use
2. Check gateway and DNS servers are reachable
3. Verify subnet mask is correct
4. Check network adapter exists (should be created by Packer)

### Windows Updates Take Too Long

Windows updates can take 30-60 minutes:

1. This is normal for first-time installation
2. Check network connectivity
3. Verify DNS resolution works
4. Check Windows Update service is running

## Reference

- [VMware Tanzu Documentation](https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/elastic-application-runtime/6-0/eart/create-vsphere-stemcell-automatically.html)
- [Packer vSphere Plugin Documentation](https://developer.hashicorp.com/packer/plugins/builders/vsphere/vsphere-iso)
