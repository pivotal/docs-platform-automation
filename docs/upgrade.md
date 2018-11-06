---
title: Upgrading PCF using Platform Automation
owner: PCF Platform Automation
---

This topic describes how to upgrade an Ops Manager using Platform Automation.

* always perform an export installation
* persist that exported installation
* installation is separate from upgrade
* an initial installation is done, which maintains state 

##Always export your installation
{% include "./_export_installation_note.md" %}

###Command Requirements

The [`upgrade-opsman`](reference/task.md#upgrade-opsman) will delete the previous VM, create a new VM, and import
a previous installation. It requires the following to perform this operations: 

* a valid [state file](reference/task.md#state) from the currently deployed Ops Manager
* a valid [image file](reference/task.md#opsman-image) for the new Ops Manager to install
* a [configuration file](reference/task.md#opsman-config) for IAAS specific details
* an [exported installation](reference/task.md#installation) from a currently deployed Ops Manager
* the [auth file](reference/task.md#auth) for a currently deployed Ops Manager

IAAS resource requirements
command requirements

##Upgrading Ops Manager
The [`upgrade-opsman`](reference/task.md#upgrade-opsman) task follows the flow based on state of an OpsManager VM.
This flowchart gives a high level overview of how the task makes decisions for an upgrade.

{% include "./upgrade-flowchart.mmd" %}

On successive invocations of task, it will offer different behaviour of the previous run.
This aids in recovering from failures (ie: from an IAAS) that occur.

###Version Check Errors:
1) <b>downgrading is not supported by Ops Manager</b> (Manual Intervention Required)

* Ops Manager does not support downgrading to a lower version. Try the upgrade again with a newer
version of Ops Manager 

2) <b>could not authenticate with Ops Manager</b> (Manual Intervention Required)

* Credentials provided in the auth file do not match the credentials of an already deployed Ops Manager
* SOLUTION: To change the credentials when upgrading an Ops Manager, you must update the password in your
Account Settings. Then, you will need to update the following two files with the changes:
  [`auth.yml`](reference/task.md#auth)
  [`env.yml`](reference/task.md#env)
  
3) <b>The Ops Manager API is inaccessible</b> (Recoverable)

* This error is fixed within the task. The task will assume that the Ops Manager VM is not 
created, and will run the [`create-vm`](reference/task.md#create-vm) and 
[`import-installation`](reference/task.md#import-installation) tasks
  
###IAAS CLI Errors

4) When the CLI for a supported IAAS fails for any reason (i.e., bad network, outage, etc) we treat this as 
an IAAS CLI error. The specific error will be returned as output, but <i><b>most errors can simply be fixed by 
re-running the `upgrade-opsman` task.</b></i> 

The following tasks can return an error from the IAAS's CLI:

* Delete the current Ops Manager VM
* Create a new Ops Manager VM