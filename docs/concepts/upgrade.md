This topic provides an overview 
of upgrading and recovering an Ops Manager using Platform Automation, 
including command requirements and common version check and IaaS CLI errors.

{% include "./.export_installation_note.md" %}

## Upgrading Ops Manager

It's important to note when upgrading your Ops Manager:

* always perform an export installation
* persist that exported installation
* installation is separate from upgrade
* an initial installation is done, which maintains state

### Upgrade Flowchart
The [`upgrade-opsman`][upgrade-opsman] task follows the flow based on state of an Ops Manager VM.
This flowchart gives a high level overview of how the task makes decisions for an upgrade.

{% include "./upgrade-flowchart.mmd" %}

On successive invocations of the task, it will offer different behaviour of the previous run.
This aids in recovering from failures (ie: from an IAAS) that occur.

### Command Requirements

The [`upgrade-opsman`][upgrade-opsman] task will delete the previous VM, create a new VM, and import
a previous installation. It requires the following to perform this operations:

* a valid [state file][state] from the currently deployed Ops Manager
* a valid [image file][opsman-image] for the new Ops Manager to install
* a [configuration file][opsman-config] for IAAS specific details
* an [exported installation][installation] from a currently deployed Ops Manager
* the [auth file][auth-file] for a currently deployed Ops Manager

## Recovering the Ops Manager VM
Using the `upgrade-opsman` task will always delete the VM.
This is done to create a consistent and simplified experience across IAASs.
For example, some IAASs have IP conflicts
if there are multiple Ops Manager VMs present.

If there is an issue during the upgrade process,
you may need to recover your Ops Manager VM. 
Recovering your VM can be done in two different ways.
Both methods require an exported installation.

1. **Recovery using the upgrade-opsman task**. Depending on the error, 
   the VM could be recovered by re-running [`upgrade-opsman`][upgrade-opsman].
   This may or may not require a change to the [state file][state],
   depending on if there is an [ensure][concourse-ensure] 
   set for the state file resource.
   
1. **Manual recovery**. The VM can always be recovered manually 
   by deploying the Ops Manager OVA, raw, or yml from Pivnet.

Below is a list of common errors when running `upgrade-opsman`.

- **Error: The Ops Manager API is inaccessible.**
Rerun the [`upgrade-opsman`][upgrade-opsman] task. The task will assume that the Ops Manager VM is not
created, and will run the [`create-vm`][create-vm] and
[`import-installation`][import-installation] tasks.

- **Error: The CLI for a supported IAAS fails.** (i.e., bad network, outage, etc)
The specific error will be returned as output, 
but most errors can be fixed 
by re-running the [`upgrade-opsman`][upgrade-opsman] task.

## Restoring the original Ops Manager VM
There may be an instance in which you want to restore a previous Ops Manager VM
before completing the upgrade process. 

To restore a previous Ops Manager VM manually, complete the steps below.
Instructions on how to run `p-automator` commands locally
can be found in the [Running Commands Locally How-to Guide][running-commands-locally]

1. Run `delete-vm`delete-vm on the failed or non-desired Ops Manager
   using the [`state.yml`][state] if applicable. 
   [`opsman.yml`][opsman-config] is required for this command.
   ```bash
   docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
   p-automator delete-vm --state-file state.yml --config opsman.yml
   ```
   
1. Run `create-vm` using either an empty [`state.yml`][state]
   or the state output by the previous step. 
   This command requires the image file from Pivnet
   of the original version that was deployed (yml, ova, raw).
   [`opsman.yml`][opsman-config] is required for this command.
    ```bash
    docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
    p-automator create-vm --config opsman.yml --image-file original-opsman-image.yml --state state.yml
    ```
   
1. Run `import-installation` using the exported installation
   backed-up before upgrading.
   This command requires the exported installation of the original Ops Manager
   and the `env.yml` used by Platform Automation
   ```bash
   docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
   om --env env.yml import-installation --installation installation.zip
   ```

Alternatively, these steps could be completed using the `upgrade-opsman` command.
This command requires all inputs described above.
```bash
docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
p-automator upgrade-opsman --state-file state.yml --config opsman.yml --image-file original-opsman-image.yml --installation installation.zip --env-file env.yml
```

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
