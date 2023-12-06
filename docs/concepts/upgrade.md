# Recovering and upgrading Tanzu Operations Manager

This topic provides an overview 
of upgrading and recovering a VMware Tanzu Operations Manager using Platform Automation Toolkit,
including common errors.

{% include "./.export_installation_note.md" %}

## Upgrading Tanzu Operations Manager

It's important to note when upgrading your Tanzu Operations Manager:

* always perform an export installation
* persist that exported installation
* installation is separate from upgrade
* an initial installation is done, which maintains state

### Upgrade flowchart
The [`upgrade-opsman`][upgrade-opsman] task follows the flow based on state of an Tanzu Operations Manager VM.
This flowchart gives a high level overview of how the task makes decisions for an upgrade.

{% include "./upgrade-flowchart.mmd" %}

On successive invocations of the task, it will offer different behaviour of the previous run.
This aids in recovering from failures (ie: from an IAAS) that occur.

## Recovering the Tanzu Operations Manager VM
Using the `upgrade-opsman` task will always delete the VM.
This is done to create a consistent and simplified experience across IAASs.
For example, some IAASs have IP conflicts
if there are multiple Tanzu Operations Manager VMs present.

If there is an issue during the upgrade process,
you may need to recover your Tanzu Operations Manager VM. 
Recovering your VM can be done in two different ways.
Both methods require an exported installation.

1. **Recovery using the upgrade-opsman task**. Depending on the error, 
   the VM could be recovered by re-running [`upgrade-opsman`][upgrade-opsman].
   This may or may not require a change to the [state file][state],
   depending on if there is an [ensure][concourse-ensure] 
   set for the state file resource.
   
1. **Manual recovery**. The VM can always be recovered manually 
   by deploying the Tanzu Operations Manager OVA, raw, or yml from Tanzu Network.

Below is a list of common errors when running `upgrade-opsman`.

- **Error: The Tanzu Operations Manager API is inaccessible.**
  Rerun the [`upgrade-opsman`][upgrade-opsman] task. The task will assume that the Tanzu Operations Manager VM is not
  created, and will run the [`create-vm`][create-vm] and
  [`import-installation`][import-installation] tasks.

- **Error: The CLI for a supported IAAS fails.** (i.e., bad network, outage, etc)
  The specific error will be returned as output, 
  but most errors can be fixed 
  by re-running the [`upgrade-opsman`][upgrade-opsman] task.

## Restoring the Original Tanzu Operations Manager VM
There may be an instance in which you want to restore a previous Tanzu Operations Manager VM
before completing the upgrade process.

It is recommended to restore a previous Tanzu Operations Manager VM manually.
The [Running Commands Locally How-to Guide][running-commands-locally]
is a helpful resource to get started with the manual process below. 

1. Run `delete-vm` on the failed or non-desired Tanzu Operations Manager
   using the [`state.yml`][state] if applicable. 
   [`opsman.yml`][opsman-config] is required for this command.
   ```bash
   docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
   p-automator delete-vm --state-file state.yml --config opsman.yml
   ```
   
1. Run `create-vm` using either an empty [`state.yml`][state]
   or the state output by the previous step. 
   This command requires the image file from Tanzu Network
   of the original version that was deployed (yml, ova, raw).
   [`opsman.yml`][opsman-config] is required for this command.
    ```bash
    docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
    p-automator create-vm --config opsman.yml --image-file original-opsman-image.yml \
    --state state.yml
    ```
   
1. Run `import-installation`.
   This command requires the exported installation of the original Tanzu Operations Manager
   and the `env.yml` used by Platform Automation Toolkit
   ```bash
   docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
   om --env env.yml import-installation --installation installation.zip
   ```

Alternatively, these steps could be completed using the `upgrade-opsman` command.
This command requires all inputs described above.
```bash
docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
p-automator upgrade-opsman --state-file state.yml \
--config opsman.yml --image-file original-opsman-image.yml \
--installation installation.zip --env-file env.yml
```

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
