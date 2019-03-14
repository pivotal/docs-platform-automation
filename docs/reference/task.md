---
title: Task Reference
owner: PCF Platform Automation
---

##  Platform Automation for PCF Tasks
This document lists each Platform Automation for PCF task,
and provides information about their intentions, inputs, and outputs.

The tasks are presented, in their entirety,
as they are found in the product.

The docker image can be used to invoke the commands in each task locally.
Use `--help` for more information. To learn more see the [Running Commands Locally][running commands locally] section.

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

!!! warning "GCP with service account"
    For GCP, if service account is used, the property associated_service_account has to be set explicitly in the `iaas_configuration` section.

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

The task does specific CLI commands for the creation of the Ops Manager VM on each IAAS. See below for more information:

**AWS**

1. Requires the image YAML file from Pivnet
2. Validates the existence of the VM if defined in the statefile, if so do nothing
3. Chooses the correct ami to use based on the provided image YAML file from Pivnet
4. Creates the vm configured via opsman config and the image YAML. This only attaches existing infrastructure to a newly created VM. This does not create any new resources
5. The public IP address, if provided, is assigned after successful creation

**Azure**

1. Requires the image YAML file from Pivnet
1. Validates the existence of the VM if defined in the statefile, if so do nothing
1. Copies the image (of the OpsMan VM from the specified region) as a blob into the specified storage account
1. Creates the OpsManager image
1. Creates a VM from the image. This will use unmanaged disk (if specified), and assign a public and/or private IP. This only attaches existing infrastructure to a newly createdVM. This does not create any new resources.

**GCP**

1. Requires the image YAML file from Pivnet
1. Validates the existence of the VM if defined in the statefile, if so do nothing
1. Creates a compute image based on the region specific Ops Manager source URI in the specified Ops Manager account
1. Creates a VM from the image. This will assign a public and/or private IP address, VM sizing, and tags. This does not create any new resources.

**Openstack**

1. Requires the image YAML file from Pivnet
1. Validates the existence of the VM if defined in the statefile, if so do nothing
1. Recreates the image in openstack if it already exists to validate we are using the correct version of the image
1. Creates a VM from the image. This does not create any new resources
1. The public IP address, if provided, is assigned after successful creation

**Vsphere**

1. Requires the OVA image from Pivnet
1. Validates the existence of the VM if defined in the statefile, if so do nothing
1. Build ipath from the provided datacenter, folder, and vmname provided in the config file. The created VM is stored on the generated path. If folder is not provided, the vm will be placed in the datacenter.
1. Creates a VM from the image provided to the `create-vm` command. This does not create any new resources


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

The task does specific CLI commands for the deletion of the Ops Manager VM and resources on each IAAS. See below for more information:

**AWS**

1. Deletes the VM

**Azure**

1. Deletes the VM
1. Attempts to delete the associated disk
1. Attempts to delete the associated nic
1. Attempts to delete the associated image

**GCP**

1. Deletes the VM
1. Attempts to delete the associated image

**Openstack**

1. Deletes the VM
1. Attempts to delete the associated image

**vSphere**

1. Deletes the VM

### download-product

{% include "./.opsman_filename_change_note.md" %}

Downloads a product specified in a config file from Pivnet.
Optionally, also downloads the latest stemcell for that product.

Downloads are cached, so files are not re-downloaded each time.

Outputs can be persisted to an S3-compatible blobstore using a `put` to an appropriate resource
for later use with the [`download-product-s3`][download-product-s3],
or used directly as inputs to [upload-and-stage-product](#upload-and-stage-product)
and [upload-stemcell](#upload-stemcell) tasks.

This task requires a [download-product config file][download-product-config].

If S3 configuration is present in the [download-product config file][download-product-config],
the slug and version of the downloaded product file will be prepended in brackets to the filename.  
For example:

- original-pivnet-filenames:
  ```
  ops-manager-aws-2.5.0-build.123.yml
  cf-2.5.0-build.45.pivotal
  ```

- download-product-filenames if S3 configuration is present:
  ```
  [ops-manager,2.5.0]ops-manager-aws-2.5.0-build.123.yml
  [elastic-runtime,2.5.0]cf-2.5.0-build.45.pivotal
  ```
  
This is to allow the same config parameters
that let us select a file from Pivnet
select it again when pulling from S3.
Note that the filename will be unchanged
if S3 keys are not present in the configuration file.
This avoids breaking current pipelines.

!!! warning "When using the s3 resource in concourse"
    If you are using a `regexp` in your s3 resource definition that explicitly requires the pivnet filename to be the _start_ of the
    regex, (i.e., the pattern starts with `^`) this won't work when using S3 config.
    The new file format preserves the original filename, so it is still possible to match on that -
    but if you need to match from the beginning of the filename, that will have been replaced by the prefix described above.

!!! info "When specifying PAS-Windows"
    This task will automatically download and inject the winfs for pas-windows.

!!! warning "When specifying PAS-Windows on Vsphere"
    This task cannot download the stemcell for pas-windows on vSphere.
    To build this stemcell manually, please reference the
    [Creating a vSphere Windows Stemcell][create-vsphere-windows-stemcell] guide
    in Pivotal Documentation.
    
!!! info "When only downloading from Pivnet"
    When the download product config only has Pivnet credentials,
    it will not add the prefix to the downloaded product.
    For example, `example-product.pivotal` from Pivnet will be outputed
    as `example-product.pivotal`.

{% code_snippet 'tasks', 'download-product' %}

### download-product-s3
Downloads a product specified in a config file from an S3-compatible blobstore.
This is useful when retrieving assets in an offline environment.

Downloads are cached, so files are not re-downloaded each time.

This is intended to be used with files downloaded from Pivnet by [`download-product`][download-product]
and then persisted to a blobstore using a `put` step.

Outputs can be used directly as an input to [upload-and-stage-product](#upload-and-stage-product)
and [upload-stemcell](#upload-stemcell) tasks.

This task requires a [download-product config file][download-product-config].
The same configuration file should be used with both this task and [`download-product`][download-product].

The product files uploaded to s3 for download with this task need a specific prefix:
`[product-slug,semantic-version]`.
This prefix is added by the [`download-product`][download-product] task
when S3 keys are present in the configuration file.
This is the meta information about the product from Pivnet,
which is not guaranteed to be in the original filename.
This tasks uses the meta information to be able to perform 

!!! info "When only downloading from Pivnet"
    When the download product config only has Pivnet credentials,
    it will not add the prefix to the downloaded product.
    For example, `example-product.pivotal` from Pivnet will be outputed
    as `example-product.pivotal`.

!!! info
    It's possible to use IAM instance credentials
    instead of providing S3 creds in the config file.
    See [download-product config file][download-product-config] for details.

{% code_snippet 'tasks', 'download-product-s3' %}

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

!!! info
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

!!! info
    This commits **all changes** present
    in the repo used for the `repository` input,
    in addition to copying in a single file.

!!! info 
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

{% include "./.opsman_filename_change_note.md" %}

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
{% include ".external_link_url.md" %}
