# Build Windows Stemcell Task

This Concourse task automates the creation of Windows Server 2019 stemcells on vSphere using Packer and stembuild. The task generates a `variables.pkrvars.hcl` file from Concourse task parameters and runs the build process.

## Overview

The task supports two build modes:
1. **ISO Mode**: Builds a new VM from a Windows Server 2019 ISO
2. **Template Mode**: Clones an existing template VM (faster, skips installation)

## Required Parameters

### vCenter Configuration (MANDATORY)
- `VCENTER_SERVER` - vCenter Server FQDN or IP
- `VCENTER_USERNAME` - vCenter username
- `VCENTER_PASSWORD` - vCenter password
- `VCENTER_INSECURE_CONNECTION` - Allow insecure connections (default: `true`)

### vSphere Infrastructure (MANDATORY)
- `VCENTER_DATACENTER` - vCenter datacenter name
- `VCENTER_DATASTORE` - vCenter datastore name
- `VCENTER_NETWORK` - vCenter network/port group name
- `VCENTER_CLUSTER` - vCenter cluster name (optional, leave empty if using host)
- `VCENTER_HOST` - vCenter ESXi host name (optional, leave empty if using cluster)
- `VCENTER_FOLDER` - vCenter folder path (optional)
- `VCENTER_RESOURCE_POOL` - vCenter resource pool name (optional)

### VM Configuration (OPTIONAL - defaults shown)
- `VM_NAME` - Temporary VM name during build (default: `windows-base-vm`)
- `VM_CPU_COUNT` - Number of CPUs (default: `8`)
- `VM_MEMORY_MB` - Memory in MB (default: `16384`)
- `VM_DISK_SIZE_GB` - Disk size in GB (default: `100`)

### Build Mode Configuration (MANDATORY - choose one)

**ISO Mode:**
- `ISO_PATH_LOCAL` - Local path to Windows Server 2019 ISO (Packer will upload)
- `ISO_PATH` - Datastore path to Windows Server 2019 ISO (e.g., `[datastore1]/ISOs/file.iso`)
- Or provide `windows-iso` input resource with ISO file

**Template Mode:**
- `TEMPLATE_PATH` - vCenter inventory path to template (e.g., `/Datacenter/vm/Templates/windows-2019-template`)

### Windows Configuration (MANDATORY)
- `WINDOWS_USERNAME` - Windows administrator username (default: `Administrator`)
- `WINDOWS_PASSWORD` - Windows administrator password

### Network Configuration (MANDATORY)
- `STATIC_IP` - Static IP address
- `SUBNET_MASK` - Subnet mask (e.g., `255.255.255.0`)
- `GATEWAY` - Default gateway
- `DNS_SERVERS` - DNS servers (comma-separated, e.g., `8.8.8.8,8.8.4.4`)

### Stemcell Configuration (MANDATORY)
- `PATCH_VERSION` - Patch version for stemcell (e.g., `2019.12.3` or `3`)

## Optional Parameters

- `TEMPLATE_NAME` - Final template name (optional, for creating template after stemcell in ISO mode)
- `HTTP_PROXY` - HTTP proxy URL (optional)
- `HTTPS_PROXY` - HTTPS proxy URL (optional)
- `NO_PROXY` - Comma-separated list of hosts that should not use proxy (optional)
- `ENABLE_WINDOWS_UPDATES` - Enable Windows updates installation (default: `true`)
- `LOG_LEVEL` - Logging level: `DEBUG`, `INFO`, `WARN`, `ERROR` (default: `INFO`)

## Inputs

- `docs-platform-automation` - Required. Contains the build scripts and Packer configuration
- `windows-iso` - Optional. Contains the Windows Server 2019 ISO file (for ISO mode)

## Outputs

- `logs` - Build logs and output files

## Example Pipelines

### Example 1: ISO Mode with S3 Resource

Build from ISO stored in S3:

```yaml
resources:
- name: docs-platform-automation
  type: git
  source:
    uri: https://github.com/pivotal/docs-platform-automation.git
    branch: develop

- name: windows-iso
  type: s3
  source:
    bucket: my-windows-isos
    regexp: windows-server-2019.*\.iso
    access_key_id: ((s3-access-key))
    secret_access_key: ((s3-secret-key))

- name: binaries-image
  type: registry-image
  source:
    repository: ((concourse-team/dev_image_registry.dev_url))/internalpcfplatformautomation/platform-automation
    tag: testing
    username: ((concourse-team/dev_image_registry.username))
    password: ((concourse-team/dev_image_registry.password))

jobs:
- name: build-windows-stemcell
  plan:
  - get: docs-platform-automation
  - get: windows-iso
    trigger: true
  - task: build-windows-stemcell
    image: binaries-image
    file: docs-platform-automation/ci/tasks/build-windows-stemcell/task.yml
    params:
      # vCenter Configuration
      VCENTER_SERVER: ((vcenter-server))
      VCENTER_USERNAME: ((vcenter-username))
      VCENTER_PASSWORD: ((vcenter-password))
      VCENTER_INSECURE_CONNECTION: "true"
      
      # vSphere Infrastructure
      VCENTER_DATACENTER: ((vcenter-datacenter))
      VCENTER_DATASTORE: ((vcenter-datastore))
      VCENTER_NETWORK: ((vcenter-network))
      VCENTER_CLUSTER: ((vcenter-cluster))
      
      # VM Configuration (using defaults)
      # VM_NAME: "windows-base-vm"  # Optional
      # VM_CPU_COUNT: "8"           # Optional
      # VM_MEMORY_MB: "16384"       # Optional
      # VM_DISK_SIZE_GB: "100"      # Optional
      
      # Build Mode: ISO from windows-iso input
      ISO_PATH_LOCAL: "windows-iso/*.iso"
      
      # Stemcell Configuration
      PATCH_VERSION: "2019.12.3"
      
      # Windows Configuration
      WINDOWS_USERNAME: "Administrator"
      WINDOWS_PASSWORD: ((windows-password))
      
      # Network Configuration
      STATIC_IP: ((static-ip))
      SUBNET_MASK: ((subnet-mask))
      GATEWAY: ((gateway))
      DNS_SERVERS: ((dns-servers))
      
      # Optional: Create template after stemcell
      TEMPLATE_NAME: "windows-2019-base-template"
      
      # Build Options
      ENABLE_WINDOWS_UPDATES: "true"
      LOG_LEVEL: "INFO"
    outputs:
    - name: logs
```

### Example 2: ISO Mode with Datastore Path

Build from ISO already uploaded to vSphere datastore:

```yaml
jobs:
- name: build-windows-stemcell
  plan:
  - get: docs-platform-automation
  - task: build-windows-stemcell
    image: binaries-image
    file: docs-platform-automation/ci/tasks/build-windows-stemcell/task.yml
    params:
      # vCenter Configuration
      VCENTER_SERVER: ((vcenter-server))
      VCENTER_USERNAME: ((vcenter-username))
      VCENTER_PASSWORD: ((vcenter-password))
      VCENTER_INSECURE_CONNECTION: "true"
      
      # vSphere Infrastructure
      VCENTER_DATACENTER: ((vcenter-datacenter))
      VCENTER_DATASTORE: ((vcenter-datastore))
      VCENTER_NETWORK: ((vcenter-network))
      VCENTER_CLUSTER: ((vcenter-cluster))
      VCENTER_FOLDER: "/Datacenter/vm/WindowsVMs"
      VCENTER_RESOURCE_POOL: "ResourcePool"
      
      # VM Configuration (custom values)
      VM_NAME: "my-windows-vm"
      VM_CPU_COUNT: "4"
      VM_MEMORY_MB: "8192"
      VM_DISK_SIZE_GB: "80"
      
      # Build Mode: ISO from datastore
      ISO_PATH: "[datastore1]/ISOs/windows-server-2019.iso"
      
      # Stemcell Configuration
      PATCH_VERSION: "3"
      
      # Windows Configuration
      WINDOWS_USERNAME: "Administrator"
      WINDOWS_PASSWORD: ((windows-password))
      
      # Network Configuration
      STATIC_IP: "192.168.1.100"
      SUBNET_MASK: "255.255.255.0"
      GATEWAY: "192.168.1.1"
      DNS_SERVERS: "8.8.8.8,8.8.4.4"
      
      # Build Options
      ENABLE_WINDOWS_UPDATES: "true"
      LOG_LEVEL: "DEBUG"
    outputs:
    - name: logs
```

### Example 3: Template Mode

Clone from existing template (faster, skips installation):

```yaml
jobs:
- name: build-windows-stemcell-from-template
  plan:
  - get: docs-platform-automation
  - task: build-windows-stemcell
    image: binaries-image
    file: docs-platform-automation/ci/tasks/build-windows-stemcell/task.yml
    params:
      # vCenter Configuration
      VCENTER_SERVER: ((vcenter-server))
      VCENTER_USERNAME: ((vcenter-username))
      VCENTER_PASSWORD: ((vcenter-password))
      VCENTER_INSECURE_CONNECTION: "true"
      
      # vSphere Infrastructure
      VCENTER_DATACENTER: ((vcenter-datacenter))
      VCENTER_DATASTORE: ((vcenter-datastore))
      VCENTER_NETWORK: ((vcenter-network))
      VCENTER_CLUSTER: ((vcenter-cluster))
      
      # Build Mode: Template
      TEMPLATE_PATH: "/Datacenter/vm/Templates/windows-2019-base-template"
      
      # Stemcell Configuration
      PATCH_VERSION: "2019.12.3"
      
      # Windows Configuration
      WINDOWS_USERNAME: "Administrator"
      WINDOWS_PASSWORD: ((windows-password))
      
      # Network Configuration
      STATIC_IP: ((static-ip))
      SUBNET_MASK: ((subnet-mask))
      GATEWAY: ((gateway))
      DNS_SERVERS: ((dns-servers))
      
      # Build Options
      ENABLE_WINDOWS_UPDATES: "true"
      LOG_LEVEL: "INFO"
    outputs:
    - name: logs
```

**Note:** Template mode automatically:
- Skips password change (assumes template already configured)
- Skips VMware Tools installation (assumes already installed)
- Always deletes VM after completion (success or failure)

### Example 4: With Proxy Configuration

Build with HTTP/HTTPS proxy:

```yaml
jobs:
- name: build-windows-stemcell-with-proxy
  plan:
  - get: docs-platform-automation
  - get: windows-iso
    trigger: true
  - task: build-windows-stemcell
    image: binaries-image
    file: docs-platform-automation/ci/tasks/build-windows-stemcell/task.yml
    params:
      # vCenter Configuration
      VCENTER_SERVER: ((vcenter-server))
      VCENTER_USERNAME: ((vcenter-username))
      VCENTER_PASSWORD: ((vcenter-password))
      VCENTER_INSECURE_CONNECTION: "true"
      
      # vSphere Infrastructure
      VCENTER_DATACENTER: ((vcenter-datacenter))
      VCENTER_DATASTORE: ((vcenter-datastore))
      VCENTER_NETWORK: ((vcenter-network))
      VCENTER_CLUSTER: ((vcenter-cluster))
      
      # Build Mode: ISO
      ISO_PATH_LOCAL: "windows-iso/*.iso"
      
      # Stemcell Configuration
      PATCH_VERSION: "2019.12.3"
      
      # Windows Configuration
      WINDOWS_USERNAME: "Administrator"
      WINDOWS_PASSWORD: ((windows-password))
      
      # Network Configuration
      STATIC_IP: ((static-ip))
      SUBNET_MASK: ((subnet-mask))
      GATEWAY: ((gateway))
      DNS_SERVERS: ((dns-servers))
      
      # Proxy Configuration
      HTTP_PROXY: "http://proxy.example.com:8080"
      HTTPS_PROXY: "http://proxy.example.com:8080"
      NO_PROXY: "localhost,127.0.0.1,.local"
      
      # Build Options
      ENABLE_WINDOWS_UPDATES: "true"
      LOG_LEVEL: "INFO"
    outputs:
    - name: logs
```

### Example 5: Using Host Instead of Cluster

Build using specific ESXi host:

```yaml
jobs:
- name: build-windows-stemcell-on-host
  plan:
  - get: docs-platform-automation
  - get: windows-iso
    trigger: true
  - task: build-windows-stemcell
    image: binaries-image
    file: docs-platform-automation/ci/tasks/build-windows-stemcell/task.yml
    params:
      # vCenter Configuration
      VCENTER_SERVER: ((vcenter-server))
      VCENTER_USERNAME: ((vcenter-username))
      VCENTER_PASSWORD: ((vcenter-password))
      VCENTER_INSECURE_CONNECTION: "true"
      
      # vSphere Infrastructure (using host instead of cluster)
      VCENTER_DATACENTER: ((vcenter-datacenter))
      VCENTER_DATASTORE: ((vcenter-datastore))
      VCENTER_NETWORK: ((vcenter-network))
      VCENTER_CLUSTER: ""  # Empty when using host
      VCENTER_HOST: "esxi-01.example.com"  # Specify host
      
      # Build Mode: ISO
      ISO_PATH_LOCAL: "windows-iso/*.iso"
      
      # Stemcell Configuration
      PATCH_VERSION: "2019.12.3"
      
      # Windows Configuration
      WINDOWS_USERNAME: "Administrator"
      WINDOWS_PASSWORD: ((windows-password))
      
      # Network Configuration
      STATIC_IP: ((static-ip))
      SUBNET_MASK: ((subnet-mask))
      GATEWAY: ((gateway))
      DNS_SERVERS: ((dns-servers))
      
      # Build Options
      ENABLE_WINDOWS_UPDATES: "true"
      LOG_LEVEL: "INFO"
    outputs:
    - name: logs
```

### Example 6: Minimal Configuration (Using Defaults)

Minimal pipeline using all defaults:

```yaml
jobs:
- name: build-windows-stemcell-minimal
  plan:
  - get: docs-platform-automation
  - get: windows-iso
    trigger: true
  - task: build-windows-stemcell
    image: binaries-image
    file: docs-platform-automation/ci/tasks/build-windows-stemcell/task.yml
    params:
      # vCenter Configuration (MANDATORY)
      VCENTER_SERVER: ((vcenter-server))
      VCENTER_USERNAME: ((vcenter-username))
      VCENTER_PASSWORD: ((vcenter-password))
      VCENTER_INSECURE_CONNECTION: "true"
      
      # vSphere Infrastructure (MANDATORY)
      VCENTER_DATACENTER: ((vcenter-datacenter))
      VCENTER_DATASTORE: ((vcenter-datastore))
      VCENTER_NETWORK: ((vcenter-network))
      VCENTER_CLUSTER: ((vcenter-cluster))
      
      # Build Mode: ISO (MANDATORY)
      ISO_PATH_LOCAL: "windows-iso/*.iso"
      
      # Stemcell Configuration (MANDATORY)
      PATCH_VERSION: "2019.12.3"
      
      # Windows Configuration (MANDATORY)
      WINDOWS_PASSWORD: ((windows-password))
      # WINDOWS_USERNAME defaults to "Administrator"
      
      # Network Configuration (MANDATORY)
      STATIC_IP: ((static-ip))
      SUBNET_MASK: ((subnet-mask))
      GATEWAY: ((gateway))
      DNS_SERVERS: ((dns-servers))
      
      # VM Configuration uses defaults:
      # VM_NAME: "windows-base-vm"
      # VM_CPU_COUNT: "8"
      # VM_MEMORY_MB: "16384"
      # VM_DISK_SIZE_GB: "100"
      
      # Build Options use defaults:
      # ENABLE_WINDOWS_UPDATES: "true"
      # LOG_LEVEL: "INFO"
    outputs:
    - name: logs
```

## Generated Variables File

The task automatically generates a `variables.pkrvars.hcl` file from the Concourse parameters. The generated file is displayed in the task output for debugging purposes.

Example generated file:

```hcl
# Generated from Concourse task inputs
# vCenter Configuration
vcenter_server              = "vcenter.example.com"
vcenter_username            = "administrator@vsphere.local"
vcenter_password            = "YourPassword"
vcenter_insecure_connection = true

# vSphere Infrastructure
vcenter_datacenter    = "Datacenter"
vcenter_cluster       = "Cluster"
vcenter_host          = ""
vcenter_datastore     = "datastore1"
vcenter_network       = "VM Network"

# VM Configuration
vm_name         = "windows-base-vm"
vm_cpu_count    = 8
vm_memory_mb    = 16384
vm_disk_size_gb = 100

# Build Mode Configuration
iso_path_local = "windows-iso/windows-server-2019.iso"

# Windows Configuration
windows_username = "Administrator"
windows_password = "YourPassword"

# Network Configuration
static_ip    = "192.168.1.100"
subnet_mask  = "255.255.255.0"
gateway      = "192.168.1.1"
dns_servers  = ["8.8.8.8", "8.8.4.4"]

# Stemcell Configuration
patch_version = "2019.12.3"

# Build Options
enable_windows_updates = true
log_level              = "INFO"
```

## Output

- **Stemcell file:** `bosh-stemcell-*-vsphere-esxi-windows2019-go_agent.tgz` (created in task working directory)
- **Logs:** Available in the `logs` output directory with detailed logs for each step

## Notes

1. **Template Mode**: When using `TEMPLATE_PATH`, the VM is always deleted after completion (success or failure). This is by design to keep the template clean.

2. **ISO Mode**: The VM is kept after successful build (for template creation if configured). On failure, the VM is cleaned up automatically.

3. **DNS Servers**: The `DNS_SERVERS` parameter accepts comma-separated values (e.g., `8.8.8.8,8.8.4.4`) and is automatically converted to HCL list format.

4. **Image Requirements**: The task requires the `binaries-image` which includes Packer, govc, and stembuild. This image is built in the CI pipeline and published to the registry.
