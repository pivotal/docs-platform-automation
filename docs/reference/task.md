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
Use `--help` for more information. To learn more see the [running-commands-locally][running-commands-locally] section.

### apply-changes

Triggers an install on the Ops Manager described by the auth file.

{% code_snippet 'tasks', 'apply-changes', 'Task' %}
{% code_snippet 'tasks', 'apply-changes-script', 'Implementation' %}
{% code_snippet 'examples', 'apply-changes-usage', 'Usage' %}

### apply-director-changes
`apply-changes` can also be used to trigger an install for just the BOSH Director
with the `--skip-deploy-products`/`-sdp` flag.

{% code_snippet 'tasks', 'apply-director-changes', 'Task' %}
{% code_snippet 'tasks', 'apply-director-changes-script', 'Implementation' %}
{% code_snippet 'examples', 'apply-director-changes-usage', 'Usage' %}

### assign-multi-stemcell
`assign-multi-stemcell` assigns multiple stemcells to a provided product.
This feature is only available in OpsMan 2.6+.
For more information on how to utilize this workflow,
check out the [Stemcell Handling][stemcell-handling] topic.

{% code_snippet 'tasks', 'assign-multi-stemcell', 'Task' %}
{% code_snippet 'tasks', 'assign-multi-stemcell-script', 'Implementation' %}
{% code_snippet 'examples', 'assign-multi-stemcell-usage', 'Usage' %}

### assign-stemcell
`assign-stemcell` assigns a stemcell to a provided product. For more information on how to utilize
this workflow, check out the [Stemcell Handling][stemcell-handling] topic.

{% code_snippet 'tasks', 'assign-stemcell', 'Task' %}
{% code_snippet 'tasks', 'assign-stemcell-script', 'Implementation' %}
{% code_snippet 'examples', 'assign-stemcell-usage', 'Usage' %}

### collect-telemetry
Collects foundation information
using the [Pivotal Telemetry][telemetry] tool.

This task requires the `telemetry-collector-binary` as an input.
The binary is available on [Pivotal Network][telemetry];
you will need to define a `resource` to supply the binary.

After using this task,
the [send-telemetry][send-telemetry]
may be used to send telemetry data to Pivotal.

You can find additional documentation about Pivotal Telemetry
at [https://docs.pivotal.io/telemetry](https://docs.pivotal.io/telemetry)

{% code_snippet 'tasks', 'collect-telemetry', 'Task' %}
{% code_snippet 'tasks', 'collect-telemetry-script', 'Implementation' %}

### configure-authentication
Configures Ops Manager with an internal userstore and admin user account.
See [configure-saml-authentication](#configure-saml-authentication) to configure an external SAML user store,
and [configure-ldap-authentication](#configure-ldap-authentication) to configure with LDAP.

{% code_snippet 'tasks', 'configure-authentication', 'Task' %}
{% code_snippet 'tasks', 'configure-authentication-script', 'Implementation' %}
{% code_snippet 'examples', 'configure-authentication-usage', 'Usage' %}

For details on the config file expected in the `config` input,
please see [Generating an Auth File][generating-an-auth-file].

### configure-director
Configures the BOSH Director with settings from a config file.
See [staged-director-config](#staged-director-config),
which can extract a config file.

{% code_snippet 'tasks', 'configure-director', 'Task' %}
{% code_snippet 'tasks', 'configure-director-script', 'Implementation' %}
{% code_snippet 'examples', 'configure-director-usage', 'Usage' %}

!!! warning "GCP with service account"
    For GCP, if service account is used, the property associated_service_account has to be set explicitly in the `iaas_configuration` section.

### configure-ldap-authentication
Configures Ops Manager with an external LDAP user store and admin user account.
See [configure-authentication](#configure-authentication) to configure an internal user store,
and [configure-saml-authentication](#configure-saml-authentication) to configure with SAML.

{% code_snippet 'tasks', 'configure-ldap-authentication', 'Task' %}
{% code_snippet 'tasks', 'configure-ldap-authentication-script', 'Implementation' %}
{% code_snippet 'examples', 'configure-ldap-authentication-usage', 'Usage' %}

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

{% code_snippet 'tasks', 'configure-product', 'Task' %}
{% code_snippet 'tasks', 'configure-product-script', 'Implementation' %}
{% code_snippet 'examples', 'configure-product-usage', 'Usage' %}

### configure-saml-authentication
Configures Ops Manager with an external SAML user store and admin user account.
See [configure-authentication](#configure-authentication) to configure an internal user store,
and [configure-ldap-authentication](#configure-ldap-authentication) to configure with LDAP.

{% code_snippet 'tasks', 'configure-saml-authentication', 'Task' %}
{% code_snippet 'tasks', 'configure-saml-authentication-script', 'Implementation' %}
{% code_snippet 'examples', 'configure-saml-authentication-usage', 'Usage' %}

!!! info "Bosh Admin Client"
    By default, this task creates a bosh admin client.
    This is helpful for some advanced workflows
    that involve communicating directly with the BOSH Director.
    It is possible to disable this behavior;
    see our [config file documentation][generating-an-auth-file] for details.

Configuring SAML has two different auth flows for the UI and the task.
The UI will have a browser based login flow.
The CLI will require `client-id` and `client-secret` as it cannot do a browser login flow.

For more details on using SAML,
please refer to the [Ops Manager documentation](https://docs.pivotal.io/pivotalcf/2-4/opsguide/config-rbac.html#enable-saml)

For details on the config file expected in the `config` input,
please see [Generating an Auth File][generating-an-auth-file].

### create-vm
Creates an unconfigured Ops Manager VM.

{% code_snippet 'tasks', 'create-vm', 'Task' %}
{% code_snippet 'tasks', 'create-vm-script', 'Implementation' %}
{% code_snippet 'examples', 'create-vm-usage', 'Usage' %}

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
1. Creates the Ops Manager image
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

{% code_snippet 'tasks', 'credhub-interpolate', 'Task' %}
{% code_snippet 'tasks', 'credhub-interpolate-script', 'Implementation' %}
{% code_snippet 'examples', 'credhub-interpolate-usage', 'Usage' %}

This task requires a valid credhub with UAA client and secret. For information on how to
set this up, see [Secrets Handling][secrets-handling]

### delete-installation
Delete the Ops Manager Installation

{% code_snippet 'tasks', 'delete-installation', 'Task' %}
{% code_snippet 'tasks', 'delete-installation-script', 'Implementation' %}
{% code_snippet 'examples', 'delete-installation-usage', 'Usage' %}

### delete-vm
Deletes the Ops Manager VM instantiated by [create-vm](#create-vm).

{% code_snippet 'tasks', 'delete-vm', 'Task' %}
{% code_snippet 'tasks', 'delete-vm-script', 'Implementation' %}
{% code_snippet 'examples', 'delete-vm-usage', 'Usage' %}

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

{% code_snippet 'tasks', 'download-product', 'Task' %}
{% code_snippet 'tasks', 'download-product-script', 'Implementation' %}
{% code_snippet 'examples', 'download-product-usage', 'Usage' %}

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
This ensures that the same file
is being captured with both tasks.

The product files uploaded to s3 for download with this task require a specific prefix:
`[product-slug,semantic-version]`.
This prefix is added by the [`download-product`][download-product] task
when S3 keys are present in the configuration file.
This is the meta information about the product from Pivnet,
which is _not guaranteed_ to be in the original filename.
This tasks uses the meta information to be able to perform
consistent downloads from s3
as defined in the provided download config.
For example:

- original-pivnet-filenames:
  ```
  ops-manager-aws-2.5.0-build.123.yml
  cf-2.5.0-build.45.pivotal
  ```

- filenames expected by `download-product-s3` in a bucket:
  ```
  [ops-manager,2.5.0]ops-manager-aws-2.5.0-build.123.yml
  [elastic-runtime,2.5.0]cf-2.5.0-build.45.pivotal
  ```

!!! info "When only downloading from Pivnet"
    When the download product config only has Pivnet credentials,
    it will not add the prefix to the downloaded product.
    For example, `example-product.pivotal` from Pivnet will be outputed
    as `example-product.pivotal`.

!!! info
    It's possible to use IAM instance credentials
    instead of providing S3 creds in the config file.
    See [download-product config file][download-product-config] for details.

{% code_snippet 'tasks', 'download-product-s3', 'Task' %}
{% code_snippet 'tasks', 'download-product-s3-script', 'Implementation' %}
{% code_snippet 'examples', 'download-product-s3-usage', 'Usage' %}

### expiring-certificates
Returns a list of certificates that are expiring within a time frame.
These certificates can be Ops Manager or Credhub certificates.
This is purely an informational task.

{% code_snippet 'tasks', 'expiring-certificates', 'Task' %}
{% code_snippet 'tasks', 'expiring-certificates-script', 'Implementation' %}
{% code_snippet 'examples', 'expiring-certificates-usage', 'Usage' %}

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

{% code_snippet 'tasks', 'export-installation', 'Task' %}
{% code_snippet 'tasks', 'export-installation-script', 'Implementation' %}
{% code_snippet 'examples', 'export-installation-usage', 'Usage' %}
{% include "./.export_installation_note.md" %}

### import-installation
Imports a previously exported installation to Ops Manager.

This is a part of the backup/restore and upgrade lifecycle processes.
This task is used after an installation has been exported and a new Ops Manager
has been deployed, but before the new Ops Manager is configured.

{% code_snippet 'tasks', 'import-installation', 'Task' %}
{% code_snippet 'tasks', 'import-installation-script', 'Implementation' %}
{% code_snippet 'examples', 'import-installation-usage', 'Usage' %}

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

{% code_snippet 'tasks', 'make-git-commit', 'Task' %}
{% code_snippet 'tasks', 'make-git-commit-script', 'Implementation' %}
{% code_snippet 'examples', 'make-git-commit-usage', 'Usage' %}

### pre-deploy-check
Checks if the Ops Manager director is configured properly and validates the configuration.
This feature is only available in Ops Manager 2.6+.
Additionally, checks each of the staged products
and validates they are configured correctly.
This task can be run at any time
and can be used a a pre-check for [`apply-changes`][apply-changes].

The checks that this task executes are:

- is configuration complete and valid
- is the network assigned
- is the availability zone assigned
- is the stemcell assigned
- what stemcell type/version is required
- are there any unset/invalid properties
- did any ops manager verifiers fail

If any of the above checks fail
the task will fail.
The failed task will provide a list of errors that need to be fixed
before an `apply-changes` could start.

{% code_snippet 'tasks', 'pre-deploy-check', 'Task' %}
{% code_snippet 'tasks', 'pre-deploy-check-script', 'Implementation' %}
{% code_snippet 'examples', 'pre-deploy-check-usage', 'Usage' %}

### send-telemetry
Sends the `.tar` output from [`collect-telemetry`][]
to Pivotal.

!!! info Telemetry Key
    In order to use this task,
    you will need to acquire a license key.
    Contact Pivot

{% code_snippet 'tasks', 'send-telemetry', 'Task' %}
{% code_snippet 'tasks', 'send-telemetry-script', 'Implementation' %}

### stage-product
Staged a product to the Ops Manager specified in the config file.

{% code_snippet 'tasks', 'stage-product', 'Task' %}
{% code_snippet 'tasks', 'stage-product-script', 'Implementation' %}
{% code_snippet 'examples', 'stage-product-usage', 'Usage' %}

### staged-config
Downloads the configuration for a product from Ops Manager.

Not to be confused with Ops Manager's
built-in [export](https://docs.pivotal.io/pivotalcf/customizing/backup-restore/backup-pcf-bbr.html#export),
which puts all deployed products and configurations into a single file,
intended for import as part of backup/restore and upgrade lifecycle processes.

{% code_snippet 'tasks', 'staged-config', 'Task' %}
{% code_snippet 'tasks', 'staged-config-script', 'Implementation' %}
{% code_snippet 'examples', 'staged-config-usage', 'Usage' %}

### staged-director-config

{% include "./.opsman_filename_change_note.md" %}

Downloads configuration for the BOSH director from Ops Manager.

{% code_snippet 'tasks', 'staged-director-config', 'Task' %}
{% code_snippet 'tasks', 'staged-director-config-script', 'Implementation' %}
{% code_snippet 'examples', 'staged-director-config-usage', 'Usage' %}

The configuration is exported to the `generated-config` output.
It does not extract credentials from Ops Manager
and replaced them all with YAML interpolation `(())` placeholders.
This is to ensure that credentials are never written to disk.
The credentials need to be provided from an external configuration when invoking [configure-director](#configure-director).

{% include ".missing_fields_opsman_director.md" %}

### test
An example task to ensure the assets and docker image are setup correctly in your concourse pipeline.

{% code_snippet 'tasks', 'test', 'Task' %}
{% code_snippet 'tasks', 'test-script', 'Implementation' %}
{% code_snippet 'examples', 'test-usage', 'Usage' %}

### test-interpolate
An example task to ensure that all required vars are present when interpolating into a base file.
For more instruction on this topic, see the [variables](../pipeline-design/variables.md) section

{% code_snippet 'tasks', 'test-interpolate', 'Task' %}
{% code_snippet 'tasks', 'test-interpolate-script', 'Implementation' %}
{% code_snippet 'examples', 'test-interpolate-usage', 'Usage' %}

### upgrade-opsman
Upgrades an existing Ops Manager to a new given Ops Manager version

{% code_snippet 'tasks', 'upgrade-opsman', 'Task' %}
{% code_snippet 'tasks', 'upgrade-opsman-script', 'Implementation' %}
{% code_snippet 'examples', 'upgrade-opsman-usage', 'Usage' %}

For more information about this task and how it works, see the [upgrade](../upgrade.md) page.

### upload-and-stage-product
Uploads and stages product to the Ops Manager specified in the config file.

{% code_snippet 'tasks', 'upload-and-stage-product', 'Task' %}
{% code_snippet 'tasks', 'upload-and-stage-product-script', 'Implementation' %}
{% code_snippet 'examples', 'upload-and-stage-product-usage', 'Usage' %}

### upload-product
Uploads a product to the Ops Manager specified in the config file.

{% code_snippet 'tasks', 'upload-product', 'Task' %}
{% code_snippet 'tasks', 'upload-product-script', 'Implementation' %}
{% code_snippet 'examples', 'upload-product-usage', 'Usage' %}

### upload-stemcell
Uploads a stemcell to Ops Manager.

Note that the filename of the stemcell must be exactly as downloaded from Pivnet.
Ops Manager parses this filename to determine the version and OS of the stemcell.

{% code_snippet 'tasks', 'upload-stemcell', 'Task' %}
{% code_snippet 'tasks', 'upload-stemcell-script', 'Implementation' %}
{% code_snippet 'examples', 'upload-stemcell-usage', 'Usage' %}

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
