

This topic provides a high level overview of upgrading an Ops Manager using Platform Automation, including command requirements and common version check and IaaS CLI errors.

It's important to note when upgrading your Ops Manager:

* always perform an export installation
* persist that exported installation
* installation is separate from upgrade
* an initial installation is done, which maintains state

## Always export your installation
{% include "./.export_installation_note.md" %}

### Upgrade Flowchart
The [`upgrade-opsman`][upgrade-opsman] task follows the flow based on state of an OpsManager VM.
This flowchart gives a high level overview of how the task makes decisions for an upgrade.

{% include "./upgrade-flowchart.mmd" %}

On successive invocations of the task, it will offer different behaviour of the previous run.
This aids in recovering from failures (ie: from an IAAS) that occur.

### Command Requirements

The [`upgrade-opsman`][upgrade-opsman] task will delete the previous VM, create a new VM, and import
a previous installation. It requires the following to perform this operations:

* a valid [state file](reference/inputs-outputs.md#state) from the currently deployed Ops Manager
* a valid [image file](reference/inputs-outputs.md#opsman-image) for the new Ops Manager to install
* a [configuration file][opsman-config] for IAAS specific details
* an [exported installation][installation] from a currently deployed Ops Manager
* the [auth file][auth-file] for a currently deployed Ops Manager

## Troubleshooting
When you are upgrading your Ops Manager you may get version check or IaaS CLI errors. For information about troubleshooting these errors, see [`Version Check Errors`][version-check-errors] and [`IaaS CLI Errors`][iaas-cli-errors] below.

### Version Check Errors
1) <b>Downgrading is not supported by Ops Manager</b> (Manual Intervention Required)

* Ops Manager does not support downgrading to a lower version.
* SOLUTION: Try the upgrade again with a newer version of Ops Manager.

2) <b>Could not authenticate with Ops Manager</b> (Manual Intervention Required)

* Credentials provided in the auth file do not match the credentials of an already deployed Ops Manager.
* SOLUTION: To change the credentials when upgrading an Ops Manager, you must update the password in your
Account Settings. Then, you will need to update the following two files with the changes:
  [`auth.yml`][auth-file]
  [`env.yml`][env]

3) <b>The Ops Manager API is inaccessible</b> (Recoverable)

* The task could not communicate with Ops Manager.
* SOLUTION: Rerun the [`upgrade-opsman`][upgrade-opsman] task. The task will assume that the Ops Manager VM is not
created, and will run the [`create-vm`][create-vm] and
[`import-installation`][import-installation] tasks.

### IAAS CLI Errors

1) When the CLI for a supported IAAS fails for any reason (i.e., bad network, outage, etc) we treat this as
an IAAS CLI error. The following tasks can return an error from the IAAS's CLI: [`delete-vm`][delete-vm], [`create-vm`][create-vm]

* SOLUTION: The specific error will be returned as output, but <i><b>most errors can simply be fixed by
re-running the `upgrade-opsman` task.</b></i>

{% include ".internal_link_url.md" %}
{% include ".external_link_url.md" %}
