# Build Windows stemcell (Concourse task)

This Concourse task builds a BOSH Windows stemcell (`.tgz`) on vSphere. It drives Packer (ISO mode) or clones an existing template (template mode), runs Windows configuration and updates, then uses **stembuild** to produce the stemcell artifact.

Use this guide if you are **not** a platform-automation expert: it explains how to wire a pipeline, pick a build mode, and where artifacts land.

---

## What you need first

1. **A Concourse team** you can `fly login` to, with a secrets store (e.g. Vault) for passwords.
2. **A container image** that contains Packer, `govc`, and stembuild (e.g. `binaries-image` / platform-automation `testing` tag). See [RESOURCES.md](./RESOURCES.md).
3. **This repository** as a git resource (branch that contains `tasks/build-windows-stemcell.sh` and `tasks/windows-automation/`).
4. **vSphere details**: vCenter address, credentials, datacenter, datastore, network (port group), and either cluster or host.
5. **A Windows admin password** and a **static IP** (with mask, gateway, DNS) reachable from the build network.

---

## Create a minimal pipeline (step by step)

### Step 1: Define resources

- **`docs-platform-automation`** — `git` resource pointing at this repo (your fork or `pivotal/docs-platform-automation`).
- **`binaries-image`** — `registry-image` for the task container (see [RESOURCES.md](./RESOURCES.md)).

Optional:

- **`windows-iso`** — only if you want Concourse to **fetch** an ISO file; otherwise you can point at an ISO **already on the datastore** (see below).

### Step 2: Add a job that gets those resources

Your job should `get: docs-platform-automation` and use `binaries-image` as the task image.

### Step 3: Add the task and declare outputs

Point `file:` at **one** of these (they are equivalent except for the git input name):

| Task file | Git input name |
|-----------|----------------|
| `docs-platform-automation/ci/tasks/build-windows-stemcell/task.yml` | `docs-platform-automation` |
| `docs-platform-automation/tasks/build-windows-stemcell.yml` | `platform-automation-tasks` |

Always declare **both** task outputs so later steps can consume them:

```yaml
outputs:
- name: logs
- name: stemcell
```

### Step 4: Pass `params`

All vCenter, network, Windows, and mode settings are **Concourse task params** (see examples below). The task script turns them into `variables.pkrvars.hcl` and runs `build.sh`.

---

## Choose how the VM is created (build mode)

The task picks **one** source (first match wins in the script):

| Priority | What you set | Meaning |
|----------|----------------|--------|
| 1 | `EXISTING_BASE_VM_NAME` | Clone an existing VM (advanced; not covered in detail here). |
| 2 | `TEMPLATE_PATH` | **Template mode** — clone from a vSphere template (no ISO, no Packer install). |
| 3 | `ISO_PATH_LOCAL` or `windows-iso` input | **ISO mode** — upload ISO from the task container into vSphere, then Packer installs Windows. |
| 4 | `ISO_PATH` | **ISO mode** — use an ISO **already on a vSphere datastore** (no upload from Concourse). |

Do **not** set `TEMPLATE_PATH` together with ISO variables unless you intend template mode; template wins over ISO when both appear in the generated vars file from the script’s ordering (template is checked first in `resolve_build_source`).

---

## 1) ISO already on vCenter (datastore path)

Use this when the `.iso` is **already uploaded** to a datastore (Datastore Browser in vSphere shows it).

**Set in params:**

- `ISO_PATH` — datastore path string Packer/vSphere understands, usually:
  - `[<datastore-name>]/<folder>/<file.iso>`
- Example: `[iscsi-storage]/ISOs/windows-2022.iso`

**Rules of thumb:**

- The name in brackets **`[` `]`** is the **datastore name** (as shown in vSphere), not necessarily the same as `VCENTER_DATASTORE` (that names where the **VM disk** is placed).
- Do **not** set `ISO_PATH_LOCAL` or `TEMPLATE_PATH` if you only want this mode.
- Omit the `windows-iso` input if you are not uploading an ISO from Concourse.

**Minimal params (in addition to vCenter / network / Windows / `PATCH_VERSION`):**

```yaml
params:
  ISO_PATH: '[my-datastore]/ISOs/windows-server-2019.iso'
  # ... VCENTER_*, STATIC_IP, SUBNET_MASK, GATEWAY, DNS_SERVERS, WINDOWS_PASSWORD, PATCH_VERSION, etc.
```

---

## 2) Template mode

Use this when you already have a **prepared Windows template** in vCenter (Tools installed, sysprep/generalization as you require). The task **clones** that template to a new VM, runs provisioning and stembuild on the clone, then **deletes only the clone**. Your **source template is not removed**.

**Set in params:**

- `TEMPLATE_PATH` — inventory path to the template, e.g. `/Datacenter/vm/Templates/my-windows-2019`
  - You can use a path relative to the datacenter; the build may resolve it via `govc`.

**Do not set** `ISO_PATH`, `ISO_PATH_LOCAL`, or rely on `windows-iso` for this mode.

**Minimal params (in addition to vCenter / network / Windows / `PATCH_VERSION`):**

```yaml
params:
  TEMPLATE_PATH: '/Datacenter/vm/Templates/windows-2019-base'
  # ... VCENTER_*, STATIC_IP, SUBNET_MASK, GATEWAY, DNS_SERVERS, WINDOWS_PASSWORD, PATCH_VERSION, etc.
```

---

## 3) Keep base VM (ISO mode only)

After a successful **ISO** build, the automation normally **deletes the Packer-created base VM** once work moves to a cloned “target” VM for stembuild. If you want to **keep** that base VM in vCenter (for debugging or to convert it manually), set:

```yaml
params:
  KEEP_BASE_VM: "true"
```

**Important:**

- Applies to **ISO mode** when there is a separate base VM and clone. It **does not** apply to template mode in the same way (there is no Packer base VM).
- Use the string **`true`** (the task writes `keep_base_vm = true` into the vars file).

---

## Output paths (where to find the stemcell and logs)

After the task succeeds, Concourse exposes **named outputs** on the task step:

| Output name | Contents |
|-------------|----------|
| **`stemcell/`** | The BOSH stemcell tarball. Exact filename follows the pattern `bosh-stemcell-*-vsphere-esxi-windows*-go_agent.tgz` (the middle part reflects Windows version, e.g. `windows2019`, `windows2022`). |
| **`logs/`** | Copies of build logs from `tasks/windows-automation/logs/` (detailed step logs). |

**Typical path inside a later step** (if the task is named `build-windows-stemcell`):

- Stemcell file: `build-windows-stemcell/stemcell/bosh-stemcell-....tgz`
- Logs: `build-windows-stemcell/logs/`

Use the **`stemcell`** output as an input to a follow-on task (for example `upload-stemcell`) with `input_mapping` / `passed` as appropriate.

---

## Full example: ISO on datastore + outputs for upload

```yaml
resources:
- name: docs-platform-automation
  type: git
  source:
    uri: git@github.com:pivotal/docs-platform-automation.git
    branch: develop
    private_key: ((git-private-key))

- name: binaries-image
  type: registry-image
  source:
    repository: ((dev_registry))/internalpcfplatformautomation/platform-automation
    tag: testing
    username: ((dev_registry_username))
    password: ((dev_registry_password))

jobs:
- name: build-windows-stemcell
  plan:
  - get: docs-platform-automation
  - task: build-windows-stemcell
    image: binaries-image
    file: docs-platform-automation/ci/tasks/build-windows-stemcell/task.yml
    params:
      VCENTER_SERVER: ((vcenter-server))
      VCENTER_USERNAME: ((vcenter-user))
      VCENTER_PASSWORD: ((vcenter-password))
      VCENTER_INSECURE_CONNECTION: "true"
      VCENTER_DATACENTER: ((vcenter-dc))
      VCENTER_DATASTORE: ((vm-datastore))
      VCENTER_NETWORK: ((vm-network))
      VCENTER_CLUSTER: ((vcenter-cluster))
      ISO_PATH: '[((iso-datastore))]/ISOs/windows-server-2019.iso'
      PATCH_VERSION: "2019.12.3"
      WINDOWS_USERNAME: "Administrator"
      WINDOWS_PASSWORD: ((windows-admin-password))
      STATIC_IP: ((vm-static-ip))
      SUBNET_MASK: "255.255.255.0"
      GATEWAY: ((vm-gateway))
      DNS_SERVERS: "8.8.8.8,8.8.4.4"
      KEEP_BASE_VM: "false"
      WINDOWS_VERSION: "2019"
    outputs:
    - name: logs
    - name: stemcell
```

---

## Full example: Template mode

```yaml
  - task: build-from-template
    image: binaries-image
    file: docs-platform-automation/ci/tasks/build-windows-stemcell/task.yml
    params:
      VCENTER_SERVER: ((vcenter-server))
      VCENTER_USERNAME: ((vcenter-user))
      VCENTER_PASSWORD: ((vcenter-password))
      VCENTER_INSECURE_CONNECTION: "true"
      VCENTER_DATACENTER: ((vcenter-dc))
      VCENTER_DATASTORE: ((vm-datastore))
      VCENTER_NETWORK: ((vm-network))
      VCENTER_CLUSTER: ((vcenter-cluster))
      TEMPLATE_PATH: '/Datacenter/vm/Templates/windows-2019-base'
      PATCH_VERSION: "2019.12.3"
      WINDOWS_USERNAME: "Administrator"
      WINDOWS_PASSWORD: ((windows-admin-password))
      STATIC_IP: ((vm-static-ip))
      SUBNET_MASK: "255.255.255.0"
      GATEWAY: ((vm-gateway))
      DNS_SERVERS: "8.8.8.8,8.8.4.4"
      WINDOWS_VERSION: "2019"
    outputs:
    - name: logs
    - name: stemcell
```

---

## Reference: common parameters

### vCenter (required)

- `VCENTER_SERVER`, `VCENTER_USERNAME`, `VCENTER_PASSWORD`
- `VCENTER_INSECURE_CONNECTION` — `"true"` or `"false"`
- `VCENTER_DATACENTER`, `VCENTER_DATASTORE`, `VCENTER_NETWORK`
- `VCENTER_CLUSTER` and/or `VCENTER_HOST` (one may be empty depending on your layout)
- Optional: `VCENTER_FOLDER`, `VCENTER_RESOURCE_POOL`

### Windows & stemcell (required)

- `WINDOWS_PASSWORD` — required for guest operations
- `WINDOWS_USERNAME` — default `Administrator` if omitted
- `PATCH_VERSION` — stembuild patch version (e.g. `2019.12.3` or `3`)
- `WINDOWS_VERSION` — `2019`, `2022`, or `2025` (default `2019`); must match stembuild and templates

### Network (required)

- `STATIC_IP`, `SUBNET_MASK`, `GATEWAY`, `DNS_SERVERS` (comma-separated for multiple DNS servers)

### Optional

- `TEMPLATE_NAME` — ISO mode: create/register a template after build (see `build.sh` behavior)
- `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`
- `ENABLE_WINDOWS_UPDATES` — default `true`
- `LOG_LEVEL` — `DEBUG`, `INFO`, `WARN`, `ERROR`
- `JUMPER_HOST`, `JUMPER_USER`, `JUMPER_PASSWORD` — run heavy steps via a jump host
- `PRODUCT_KEY` — optional Windows product key for unattended setup
- `DEBUG_MODE` — `"true"` enables shell trace in logs

---

## Alternate task definition (zip / renamed git resource)

If your pipeline uses the packaged tasks zip and input name `platform-automation-tasks`, use:

`file: platform-automation-tasks/tasks/build-windows-stemcell.yml`

See [RESOURCES.md](./RESOURCES.md).

---

## Notes

1. **Image**: The task container must include Packer, `govc`, and the correct **stembuild** binary for `WINDOWS_VERSION` (e.g. `stembuild-2019`, `stembuild-2022`).
2. **Datastore ISO path** is only for the **ISO file location**; VM disks still use `VCENTER_DATASTORE` unless your Packer/vars configuration says otherwise.
3. **Template mode** deletes the **temporary clone**, not your template.
4. **Keep base VM** retains the **Packer base VM** in ISO mode when a clone is used for stembuild; set `KEEP_BASE_VM: "true"` explicitly.
