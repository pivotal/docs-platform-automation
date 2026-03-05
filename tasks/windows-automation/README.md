# Windows VM Automation

Automated Windows Server 2019 VM creation and BOSH stemcell packaging for vSphere using Packer and stembuild.

## Supported Commands

### Build from ISO

Creates a new VM from a Windows Server 2019 ISO, installs Windows, configures network, installs updates, and creates a stemcell.

```bash
./build.sh -f variables.pkrvars.hcl
```

### Build from Template

Clones an existing template VM, configures network, installs updates, and creates a stemcell. Skips first-boot wait and VMware Tools installation.

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
   - Waits for first boot and auto-login (unattend sets UserAccounts + AutoLogon; no password-change screen), then mounts/installs VMware Tools
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

## Stembuild construct on jumper

When you pass `--jumper-ip`, `--jumper-user`, and `--jumper-password`, **stembuild construct** runs on the jumper host instead of locally. The build script:

- Copies `run-stembuild-construct.sh`, the stembuild binary for your `windows_version` (e.g. `stembuild-2019`), `govc`, and `LGPO.zip` to the jumper.
- Exports **GOVC_URL**, **GOVC_USERNAME**, **GOVC_PASSWORD**, **GOVC_INSECURE** (and optionally **VCENTER_CA_CERTS**) on the jumper so the construct script can talk to vCenter.
- **Captures all jumper session output** to a local log file: `logs/stembuild-construct-<timestamp>.log`.
- On failure, prints the **last 200 lines** of that log so you see the stembuild/govc errors without logging into the jumper.

To use a custom vCenter CA certificate on the jumper, set **VCENTER_CA_CERTS** to the path of your CA file before running the build; the file will be copied to the jumper as `~/vcenter-ca-certs.pem` and used by `run-stembuild-construct.sh`.

## Govc keystroke reliability (VMware Tools install)

Only **VMware Tools install** uses **govc vm.keystrokes** (unattend handles auto-login; no password-change step). Keystrokes depend on screen state, focus, and timing.

**To improve reliability:**

1. **Use a consistent Windows image** – Same Server edition and update level reduces UI differences.
2. **Tune delays** – For slow or busy VMs, set these **environment variables** before running the build (or in Concourse task params):
   - **VMware Tools** (`install-vmware-tools-keystrokes.sh`):
     - `KEYSTROKE_WAIT_BEFORE=20` (default 10) – seconds after first-boot wait before sending Tools install keystrokes
     - `KEYSTROKE_SLEEP_SHORT=2`, `KEYSTROKE_SLEEP_MEDIUM=5`
3. **Assumptions** – Script assumes US keyboard and that the desktop or console is ready (e.g. after auto-login). Non‑US layouts may need script changes.

4. **Step 1 flow** – After the global 10-minute install wait, the script waits **WAIT_BEFORE_PASSWORD_CHANGE_SECONDS** (default 60) for first boot/auto-login, then mounts VMware Tools ISO and runs the Tools install keystrokes once, then polls for guest ops. If the guest-ops check returns an **auth error**, the build **fails immediately**; otherwise we keep polling until ready or timeout.

5. **Why verification failed** – If the guest-ops check times out (or fails with auth), the build logs a **failure reason** and the raw govc error:
   - **auth_error** – Authentication failed (wrong password or user not logged in). **Build fails immediately** when this is detected during the poll; no further waiting.
   - **tools_not_ready** – VMware Tools not ready or guest operations unavailable. Wait longer or check Tools install.
   - **powershell_error** – Guest process started but PowerShell exited non-zero (e.g. login state or command failed).
   - **guest_error** – Other guest.start failure (govc error message is printed).

**Alternatives:** Once VMware Tools is installed and the user is logged in, all further steps use **guest.start** (PowerShell) and do not rely on keystrokes. Template mode skips first-boot wait and Tools install entirely.

## Requirements

- Packer 1.7.0+
- govc (VMware vSphere CLI)
- **stembuild binary** – Version-specific binaries named `stembuild-2019`, `stembuild-2022`, `stembuild-2025`. The script uses the one matching `windows_version` from your vars file and fails if not found. Optional: set env **STEMBUILD_BIN_DIR** to the directory containing those binaries; otherwise the script looks in SCRIPT_DIR and PATH (Dockerfile.binaries puts stembuild-2019 in /usr/bin).
- Access to vCenter with appropriate permissions
- Windows Server 2019/2022/2025 ISO (for ISO mode) or existing template (for template mode)
