---
title: Task Reference
owner: PCF Platform Automation
---

##  Platform Automation for PCF Tasks
This document lists each Platform Automation for PCF task,
and provides information about their intentions, inputs, and outputs.

The tasks are presented, in their entirety,
as they are found in the product.

The docker image can be used to invoke the tasks in each task locally.
Use `--help` for more information.

### apply-changes

Triggers an install on the Ops Manager described by the auth file.

{% code_snippet 'tasks', 'apply-changes' %}

### apply-director-changes
`apply-changes` can also be used to trigger an install for just the BOSH Director
with the `--skip-deploy-products`/`-sdp` flag.

{% code_snippet 'tasks', 'apply-director-changes' %}

### assign-stemcell
`assign-stemcell` assigns a stemcell to a provided product. For more information on how to utilize
this workflow, check out the [Stemcell Handling][stemcell-handling] topic.

{% code_snippet 'tasks', 'assign-stemcell' %}

### configure-authentication
Configures Ops Manager with an internal userstore and admin user account.
See [configure-saml-authentication](#configure-saml-authentication) to configure an external SAML user store,
and [configure-ldap-authentication](#configure-ldap-authentication) to configure with LDAP.

{% code_snippet 'tasks', 'configure-authentication' %}

For details on the config file expected in the `config` input,
please see [Generating an Auth File][generating-an-auth-file].

### configure-director
Configures the BOSH Director with settings from a config file.
See [staged-director-config](#staged-director-config),
which can extract a config file.

{% code_snippet 'tasks', 'configure-director' %}

!!! warning
    For GCP, if service account is used, the property associated_service_account has to be set explicitly in the iaas-configuration section.
    
### configure-ldap-authentication
Configures Ops Manager with an external LDAP user store and admin user account.
See [configure-authentication](#configure-authentication) to configure an internal user store,
and [configure-saml-authentication](#configure-saml-authentication) to configure with SAML.

{% code_snippet 'tasks', 'configure-ldap-authentication' %}

For more details on using LDAP,
please refer to the [Ops Manager documentation](https://docs.pivotal.io/pivotalcf/opsguide/auth-sso.html#configure-ldap).

For details on the config file expected in the `config` input,
please see [Generating an Auth File][generating-an-auth-file].

### configure-product
Configures an individual, staged product with settings from a config file.

Not to be confused with Ops Manager's
built-in [import](https://docs.pivotal.io/pivotalcf/customizing/backup-restore/restore-pcf-bbr.html#deploy-import),
which reads all deployed products and configurations from a single opaque file,
intended for import as part of backup/restore and upgrade lifecycle processes.

See [staged-config](#staged-config),
which can extract a config file,
and [upload-and-stage-product](#upload-and-stage-product),
which can stage a product that's been uploaded.

{% code_snippet 'tasks', 'configure-product' %}

### configure-saml-authentication
Configures Ops Manager with an external SAML user store and admin user account.
See [configure-authentication](#configure-authentication) to configure an internal user store,
and [configure-ldap-authentication](#configure-ldap-authentication) to configure with LDAP.

{% code_snippet 'tasks', 'configure-saml-authentication' %}

Configuring SAML has two different auth flows for the UI and the task.
The UI will have a browser based login flow.
The CLI will require `client-id` and `client-secret` as it cannot do a browser login flow.

For more details on using SAML,
please refer to the [Ops Manager documentation](https://docs.pivotal.io/pivotalcf/2-2/opsguide/config-rbac.html#enable-saml)

For details on the config file expected in the `config` input,
please see [Generating an Auth File][generating-an-auth-file].

### create-vm
Creates an unconfigured Ops Manager VM.

{% code_snippet 'tasks', 'create-vm' %}

This task requires a config file specific to the IaaS being deployed to.
Please see the [configuration][opsman-config] page for more specific examples.

### credhub-interpolate
Interpolate credhub entries into configuration files

{% code_snippet 'tasks', 'credhub-interpolate' %}

This task requires a valid credhub with UAA client and secret. For information on how to
set this up, see [Secrets Handling][secrets-handling]

### delete-installation
Delete the Ops Manager Installation

{% code_snippet 'tasks', 'delete-installation' %}

### delete-vm
Deletes the Ops Manager VM instantiated by [create-vm](#create-vm).

{% code_snippet 'tasks', 'delete-vm' %}

This task requires the [state file][state] generated [create-vm](#create-vm).

### download-product
Downloads a product specified in a config file from Pivnet.
Optionally, also downloads the latest stemcell for that product.

Downloads are cached, so they are not hitting Pivnet each time.
When a file is downloaded, integrity is ensured by using the SHA256 from Pivnet.

Outputs can be persisted to a blobstore,
or used directly as inputs to [upload-and-stage-product](#upload-and-stage-product)
and [upload-stemcell](#upload-stemcell) tasks.

This task requires a [download-product config file][download-product-config].

{% code_snippet 'tasks', 'download-product' %}

### export-installation
Exports an existing Ops Manager to a file.

This is the first part of the backup/restore and upgrade lifecycle processes.
This task is used on a fully installed and healthy Ops Manager to export
settings to an upgraded version of Ops Manager.

To use with non-versioned blobstore, you can override `INSTALLATION_FILE` param
to include `$timestamp`, then the generated installation file will include a sortable
timestamp in the filename.

example:
```yaml
params:
  INSTALLATION_FILE: installation-$timestamp.zip
```

!!! note
    The timestamp is generated using the time on concourse worker.
    If the time is different on different workers, the generated timestamp may fail to sort correctly.
    Changing the time or timezone on workers might interfere with ordering.

{% code_snippet 'tasks', 'export-installation' %}
{% include "./.export_installation_note.md" %}

### import-installation
Imports a previously exported installation to Ops Manager.

This is a part of the backup/restore and upgrade lifecycle processes.
This task is used after an installation has been exported and a new Ops Manager
has been deployed, but before the new Ops Manager is configured.

{% code_snippet 'tasks', 'import-installation' %}

### make-git-commit
Copies a single file into a repo and makes a commit.
Useful for persisting the state output of tasks that manage the vm, such as:

- [create-vm](#create-vm)
- [upgrade-opsman](#upgrade-opsman)
- [delete-vm](#delete-vm)

Also useful for persisting the configuration output from:

- [staged-config](#staged-config)
- [staged-director-config](#staged-director-config)

!!! note
    This commits **all changes** present
    in the repo used for the `repository` input,
    in addition to copying in a single file.

!!! note
    This does not perform a `git push`!
    You will need to `put` the output of this task to a git resource to persist it.

{% code_snippet 'tasks', 'make-git-commit' %}

### stage-product
Staged a product to the Ops Manager specified in the config file.

{% code_snippet 'tasks', 'stage-product' %}

### staged-config
Downloads the configuration for a product from Ops Manager.

Not to be confused with Ops Manager's
built-in [export](https://docs.pivotal.io/pivotalcf/2-1/customizing/backup-restore/backup-pcf-bbr.html#export),
which puts all deployed products and configurations into a single file,
intended for import as part of backup/restore and upgrade lifecycle processes.

{% code_snippet 'tasks', 'staged-config' %}

### staged-director-config
Downloads configuration for the BOSH director from Ops Manager.

{% code_snippet 'tasks', 'staged-director-config' %}

The configuration is exported to the `generated-config` output.
It does not extract credentials from Ops Manager
and replaced them all with YAML interpolation `(())` placeholders.
This is to ensure that credentials are never written to disk.
The credentials need to be provided from an external configuration when invoking [configure-director](#configure-director).

{% include ".missing_fields_opsman_director.md" %}

### test
An example task to ensure the assets and docker image are setup correctly in your concourse pipeline.

{% code_snippet 'tasks', 'test' %}

### test-interpolate
An example task to ensure that all required vars are present when interpolating into a base file.
For more instruction on this topic, see the [variables](../pipeline-design/variables.md) section

{% code_snippet 'tasks', 'test-interpolate' %}

### upgrade-opsman
Upgrades an existing Ops Manager to a new given Ops Manager version

{% code_snippet 'tasks', 'upgrade-opsman' %}

For more information about this task and how it works, see the [upgrade](../upgrade.md) page.

### upload-and-stage-product
Uploads and stages product to the Ops Manager specified in the config file.

{% code_snippet 'tasks', 'upload-and-stage-product' %}

### upload-product
Uploads a product to the Ops Manager specified in the config file.

{% code_snippet 'tasks', 'upload-product' %}

### upload-stemcell
Uploads a stemcell to Ops Manager.

Note that the filename of the stemcell must be exactly as downloaded from Pivnet.
Ops Manager parses this filename to determine the version and OS of the stemcell.

{% code_snippet 'tasks', 'upload-stemcell' %}

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
