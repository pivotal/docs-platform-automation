## Platform Automation Toolkit Tasks
This document lists each Platform Automation Toolkit task,
and provides information about their intentions, inputs, and outputs.

The tasks are presented, in their entirety,
as they are found in the product.

The docker image can be used to invoke the commands in each task locally.
Use `--help` for more information. 
To learn more see the [running-commands-locally][running-commands-locally] section.

### apply-changes

Triggers an install on the Ops Manager described by the auth file.

To optionally provide an errand file to manually control errands
for a particular of run of `apply-changes`.
To see an example of this config file, see the [Inputs and Outputs][errand-config] section.

{% include '.disable-verifiers.md' %}

=== "Task"
    ---excerpt--- "tasks/apply-changes"
=== "Implementation"
    ---excerpt--- "tasks/apply-changes-script"
=== "Usage"
    ---excerpt--- "reference/apply-changes-usage"

### apply-director-changes
`apply-changes` can also be used to trigger an install for just the BOSH Director
with the `--skip-deploy-products`/`-sdp` flag.

{% include '.disable-verifiers.md' %}

=== "Task"
    ---excerpt--- "tasks/apply-director-changes"
=== "Implementation"
    ---excerpt--- "tasks/apply-director-changes-script"
=== "Usage"
    ---excerpt--- "reference/apply-director-changes-usage"

### assign-multi-stemcell
`assign-multi-stemcell` assigns multiple stemcells to a provided product.
This feature is only available in OpsMan 2.6+.
For more information on how to utilize this workflow,
check out the [Stemcell Handling][stemcell-handling] topic.

=== "Task"
    ---excerpt--- "tasks/assign-multi-stemcell"
=== "Implementation"
    ---excerpt--- "tasks/assign-multi-stemcell-script"
=== "Usage"
    ---excerpt--- "examples/assign-multi-stemcell-usage"

### assign-stemcell
`assign-stemcell` assigns a stemcell to a provided product.
For more information on how to utilize
this workflow, check out the [Stemcell Handling][stemcell-handling] topic.

=== "Task"
    ---excerpt--- "tasks/assign-stemcell"
=== "Implementation"
    ---excerpt--- "tasks/assign-stemcell-script"
=== "Usage"
    ---excerpt--- "examples/assign-stemcell-usage"

### backup-director

Use BBR to backup a BOSH director deployed with Ops Manager.

=== "Task"
    ---excerpt--- "tasks/backup-director"
=== "Implementation"
    ---excerpt--- "tasks/backup-director-script"
=== "Usage"
    ---excerpt--- "examples/backup-director-usage"
    
### backup-product

Use BBR to backup a product deployed with Ops Manager.

=== "Task"
    ---excerpt--- "tasks/backup-product"
=== "Implementation"
    ---excerpt--- "tasks/backup-product-script"
=== "Usage"
    ---excerpt--- "examples/backup-product-usage"
    
### backup-tkgi

Use BBR to backup Tanzu Kubernetes Grid Integrated Edition(TKGI)
deployed with Ops Manager.

!!! info "PKS CLI may be Temporarily Unavailable"
    During the backup, the PKS CLI is disabled.
    Due to the nature of the backup, some commands may not work as expected.

=== "Task"
    ---excerpt--- "tasks/backup-tkgi"
=== "Implementation"
    ---excerpt--- "tasks/backup-tkgi-script"
=== "Usage"
    ---excerpt--- "examples/backup-tkgi-usage"

### check-pending-changes
Returns a table of the current state of your Ops Manager
and lists whether each product is changed or unchanged and the errands for that product.
By default, `ALLOW_PENDING_CHANGES: false` will force the task to fail.
This is useful to keep manual changes from being accidentally applied
when automating the [configure-product][configure-product]/[apply-changes][apply-changes] of other products.

=== "Task"
    ---excerpt--- "tasks/check-pending-changes"
=== "Implementation"
    ---excerpt--- "tasks/check-pending-changes-script"
=== "Usage"
    ---excerpt--- "reference/check-pending-changes-usage"

### collect-telemetry
Collects foundation information
using the [Telemetry Collector][telemetry-docs] tool.

This task requires the `telemetry-collector-binary` as an input.
The binary is available on [Tanzu Network][telemetry];
you will need to define a `resource` to supply the binary.

This task requires a [config file][telemetry-config].

After using this task,
the [send-telemetry][send-telemetry]
may be used to send telemetry data to VMware.

=== "Task"
    ---excerpt--- "tasks/collect-telemetry"
=== "Implementation"
    ---excerpt--- "tasks/collect-telemetry-script"
=== "Usage"
    ---excerpt--- "reference/collect-telemetry-usage"

### configure-authentication
Configures Ops Manager with an internal userstore and admin user account.
See [configure-saml-authentication](#configure-saml-authentication) to configure an external SAML user store,
and [configure-ldap-authentication](#configure-ldap-authentication) to configure with LDAP.

=== "Task"
    ---excerpt--- "tasks/configure-authentication"
=== "Implementation"
    ---excerpt--- "tasks/configure-authentication-script"
=== "Usage"
    ---excerpt--- "reference/configure-authentication-usage"

For details on the config file expected in the `config` input,
please see [Generating an Auth File][generating-an-auth-file].

### configure-director
Configures the BOSH Director with settings from a config file.
See [staged-director-config](#staged-director-config),
which can extract a config file.

=== "Task"
    ---excerpt--- "tasks/configure-director"
=== "Implementation"
    ---excerpt--- "tasks/configure-director-script"
=== "Usage"
    ---excerpt--- "reference/configure-director-usage"

!!! warning "GCP with service account"
    For GCP, if service account is used, the property associated_service_account has to be set explicitly in the `iaas_configuration` section.

### configure-ldap-authentication
Configures Ops Manager with an external LDAP user store and admin user account.
See [configure-authentication](#configure-authentication) to configure an internal user store,
and [configure-saml-authentication](#configure-saml-authentication) to configure with SAML.

=== "Task"
    ---excerpt--- "tasks/configure-ldap-authentication"
=== "Implementation"
    ---excerpt--- "tasks/configure-ldap-authentication-script"
=== "Usage"
    ---excerpt--- "examples/configure-ldap-authentication-usage"

For more details on using LDAP,
please refer to the [Ops Manager documentation][config-ldap].

For details on the config file expected in the `config` input,
please see [Generating an Auth File][generating-an-auth-file].

### configure-opsman
This task supports configuring settings
on the Ops Manager Settings page in the UI.
For example, the SSL cert for the Ops Manager VM can be configured.

Configuration can be added directly to [`opsman.yml`][inputs-outputs-configure-opsman].
An example of all configurable properties can be found in the "Additional Settings" tab.

The [`upgrade-opsman`][upgrade-opsman] task will automatically call `configure-opsman`,
so there is no need to use this task then.
It is recommended to use this task in the initial setup of the Ops Manager VM.

=== "Task"
    ---excerpt--- "tasks/configure-opsman"
=== "Implementation"
    ---excerpt--- "tasks/configure-opsman-script"
=== "Usage"
    ---excerpt--- "reference/configure-opsman-usage"

### configure-product
Configures an individual, staged product with settings from a config file.

Not to be confused with Ops Manager's
built-in [import][bbr-import],
which reads all deployed products and configurations from a single opaque file,
intended for import as part of backup/restore and upgrade lifecycle processes.

See [staged-config](#staged-config),
which can extract a config file,
and [upload-and-stage-product](#upload-and-stage-product),
which can stage a product that's been uploaded.

=== "Task"
    ---excerpt--- "tasks/configure-product"
=== "Implementation"
    ---excerpt--- "tasks/configure-product-script"
=== "Usage"
    ---excerpt--- "reference/configure-product-usage"

### configure-saml-authentication
Configures Ops Manager with an external SAML user store and admin user account.
See [configure-authentication](#configure-authentication) to configure an internal user store,
and [configure-ldap-authentication](#configure-ldap-authentication) to configure with LDAP.

=== "Task"
    ---excerpt--- "tasks/configure-saml-authentication"
=== "Implementation"
    ---excerpt--- "tasks/configure-saml-authentication-script"
=== "Usage"
    ---excerpt--- "examples/configure-saml-authentication-usage"

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
please refer to the [Ops Manager documentation][config-saml]

For details on the config file expected in the `config` input,
please see [Generating an Auth File][generating-an-auth-file].

### create-vm
Creates an unconfigured Ops Manager VM.

=== "Task"
    ---excerpt--- "tasks/create-vm"
=== "Implementation"
    ---excerpt--- "tasks/create-vm-script"
=== "Usage"
    ---excerpt--- "reference/create-vm-usage"

This task requires a config file specific to the IaaS being deployed to.
Please see the [configuration][opsman-config] page for more specific examples.

The task does specific CLI commands for the creation of the Ops Manager VM on each IAAS. See below for more information:

**AWS**

1. Requires the image YAML file from Tanzu Network
2. Validates the existence of the VM if defined in the statefile, if so do nothing
3. Chooses the correct ami to use based on the provided image YAML file from Tanzu Network
4. Creates the VM configured via opsman config and the image YAML. This only attaches existing infrastructure to a newly created VM. This does not create any new resources
5. The public IP address, if provided, is assigned after successful creation

**Azure**

1. Requires the image YAML file from Tanzu Network
1. Validates the existence of the VM if defined in the statefile, if so do nothing
1. Copies the image (of the OpsMan VM from the specified region) as a blob into the specified storage account
1. Creates the Ops Manager image
1. Creates a VM from the image. This will use unmanaged disk (if specified), and assign a public and/or private IP. This only attaches existing infrastructure to a newly createdVM. This does not create any new resources.

**GCP**

1. Requires the image YAML file from Tanzu Network
1. Validates the existence of the VM if defined in the statefile, if so do nothing
1. Creates a compute image based on the region specific Ops Manager source URI in the specified Ops Manager account
1. Creates a VM from the image. This will assign a public and/or private IP address, VM sizing, and tags. This does not create any new resources.

**Openstack**

1. Requires the image YAML file from Tanzu Network
1. Validates the existence of the VM if defined in the statefile, if so do nothing
1. Recreates the image in openstack if it already exists to validate we are using the correct version of the image
1. Creates a VM from the image. This does not create any new resources
1. The public IP address, if provided, is assigned after successful creation

**Vsphere**

1. Requires the OVA image from Tanzu Network
1. Validates the existence of the VM if defined in the statefile, if so do nothing
1. Build ipath from the provided datacenter, folder, and vmname provided in the config file. The created VM is stored on the generated path. If folder is not provided, the VM will be placed in the datacenter.
1. Creates a VM from the image provided to the `create-vm` command. This does not create any new resources


### credhub-interpolate
Interpolate credhub entries into configuration files

!!! info "prepare-tasks-with-secrets"
      The [prepare-tasks-with-secrets] task replaces the credhub-interpolate task on Concourse versions 5.x+
      and provides additional benefits.

=== "Task"
    ---excerpt--- "tasks/credhub-interpolate"
=== "Implementation"
    ---excerpt--- "tasks/credhub-interpolate-script"
=== "Usage"
    ---excerpt--- "examples/credhub-interpolate-usage"

This task requires a valid credhub with UAA client and secret. For information on how to
set this up, see [Secrets Handling][secrets-handling]

### delete-installation
Delete the Ops Manager Installation

=== "Task"
    ---excerpt--- "tasks/delete-installation"
=== "Implementation"
    ---excerpt--- "tasks/delete-installation-script"
=== "Usage"
    ---excerpt--- "reference/delete-installation-usage"

### delete-vm
Deletes the Ops Manager VM instantiated by [create-vm](#create-vm).

=== "Task"
    ---excerpt--- "tasks/delete-vm"
=== "Implementation"
    ---excerpt--- "tasks/delete-vm-script"
=== "Usage"
    ---excerpt--- "reference/delete-vm-usage"

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

### download-and-upload-product
This is an _advanced task_.
If a product (and its associated stemcell) has already been uploaded to Ops Manager
then it will not re-download and upload.
This is helpful when looking for a fast-feedback loop for building pipelines.

This task is similar to [`download-product`][download-product],
as it takes the same product config.
There are no `outputs` for this task
because the products (and stemcell) don't need to be shared downstream.

!!! warning
    This currently only works with product source being Tanzunet (Pivotal Network).

=== "Task"
    ---excerpt--- "tasks/download-and-upload-product"
=== "Implementation"
    ---excerpt--- "tasks/download-and-upload-product-script"
=== "Usage"
    ---excerpt--- "examples/download-and-upload-product-usage"

### download-product

{% include "./.opsman_filename_change_note.md" %}

Downloads a product specified in a config file from Tanzu Network(`pivnet`), S3(`s3`), GCS(`gcs`), or Azure(`azure`).
Optionally, also downloads the latest stemcell for that product.

Downloads are cached, so files are not re-downloaded each time.
When downloading from Tanzu Network,
the cached file is verified
using the Tanzu Network checksum
to validate the integrity of that file.
If it does not, the file is re-downloaded.
When downloading from a supported blobstore
the cached file is not-verified,
as there is no checksum from those blobstore APIs to use.

Outputs can be persisted to any supported blobstore using a `put` to an appropriate resource
for later use with download-product using the `SOURCE` parameter,
or used directly as inputs to [upload-and-stage-product](#upload-and-stage-product)
and [upload-stemcell](#upload-stemcell) tasks.

This task requires a [download-product config file][download-product-config].

If stemcell-iaas is specified in the [download-product config file][download-product-config],
and the specified product is a `.pivotal` file,
`download-product` will attempt to download the stemcell for the product.
It will retrieve the latest compatible stemcell for the specified IaaS.
The valid IaaSs are:

- `aws`
- `azure`
- `google`
- `openstack`
- `vsphere`

If a configuration for S3, GCS, or Azure is present in the [download-product config file][download-product-config],
the slug and version of the downloaded product file will be prepended in brackets to the filename.  
For example:

- original-pivnet-filenames:
  ```
  ops-manager-aws-2.5.0-build.123.yml
  cf-2.5.0-build.45.pivotal
  ```

- download-product-filenames if blobstore configuration is present:
  ```
  [ops-manager,2.5.0]ops-manager-aws-2.5.0-build.123.yml
  [elastic-runtime,2.5.0]cf-2.5.0-build.45.pivotal
  ```

This is to allow the same config parameters
that let us select a file from Tanzu Network
select it again when pulling from the supported blobstore.
Note that the filename will be unchanged
if supported blobstore keys are not present in the configuration file.
This avoids breaking current pipelines.

!!! warning "When using the s3 resource in concourse"
    If you are using a `regexp` in your s3 resource definition
    that explicitly requires the Tanzu Network filename
    to be the _start_ of the regex, (i.e., the pattern starts with `^`)
    this won't work when using S3 config.
    The new file format preserves the original filename,
    so it is still possible to match on that -
    but if you need to match from the beginning of the filename,
    that will have been replaced by the prefix described above.

!!! info "When specifying Tanzu Application Service-Windows"
    This task will automatically download and inject the winfs for pas-windows.

!!! warning "When specifying Tanzu Application Service-Windows on Vsphere"
    This task cannot download the stemcell for pas-windows on vSphere.
    To build this stemcell manually, please reference the
    [Creating a vSphere Windows Stemcell][create-vsphere-windows-stemcell] guide
    in VMware Documentation.

!!! info "When only downloading from Tanzu Network"
    When the download product config only has Tanzu Network credentials,
    it will not add the prefix to the downloaded product.
    For example, `example-product.pivotal` from Tanzu Network will be outputed
    as `example-product.pivotal`.

=== "Task"
    ---excerpt--- "tasks/download-product"
=== "Implementation"
    ---excerpt--- "tasks/download-product-script"
=== "Tanzu Network Usage"
    ---excerpt--- "reference/download-product-usage"
=== "S3 Usage"
    ---excerpt--- "reference/download-product-usage-s3"
=== "GCS Usage"
    ---excerpt--- "examples/download-product-usage-gcs"
=== "Azure Usage"
    ---excerpt--- "examples/download-product-usage-azure"

### expiring-certificates
Returns a list of certificates that are expiring within a time frame.
These certificates can be Ops Manager or Credhub certificates.
Root CAs cannot be included in this list until Ops Manager 2.7.
This is purely an informational task.

=== "Task"
    ---excerpt--- "tasks/expiring-certificates"
=== "Implementation"
    ---excerpt--- "tasks/expiring-certificates-script"
=== "Usage"
    ---excerpt--- "reference/expiring-certificates-usage"

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

=== "Task"
    ---excerpt--- "tasks/export-installation"
=== "Implementation"
    ---excerpt--- "tasks/export-installation-script"
=== "Usage"
    ---excerpt--- "reference/export-installation-usage"

{% include "./.export_installation_note.md" %}

### import-installation
Imports a previously exported installation to Ops Manager.

This is a part of the backup/restore and upgrade lifecycle processes.
This task is used after an installation has been exported and a new Ops Manager
has been deployed, but before the new Ops Manager is configured.

=== "Task"
    ---excerpt--- "tasks/import-installation"
=== "Implementation"
    ---excerpt--- "tasks/import-installation-script"
=== "Usage"
    ---excerpt--- "examples/import-installation-usage"

### make-git-commit
Copies a single file into a repo and makes a commit.
Useful for persisting the state output of tasks that manage the VM, such as:

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

=== "Task"
    ---excerpt--- "tasks/make-git-commit"
=== "Implementation"
    ---excerpt--- "tasks/make-git-commit-script"
=== "Usage"
    ---excerpt--- "examples/make-git-commit-usage"

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

=== "Task"
    ---excerpt--- "tasks/pre-deploy-check"
=== "Implementation"
    ---excerpt--- "tasks/pre-deploy-check-script"
=== "Usage"
    ---excerpt--- "reference/pre-deploy-check-usage"

### prepare-image
This task modifies the container image with runtime dependencies.
`CA_CERTS` can be added,
which can help secure HTTP connections with a proxy server
and allows the use of a custom CA on the Ops Manager.

!!! warn "Concourse 5+ Only"
    This task uses a Concourse feature
    that allows inputs and outputs to have the same name.
    This feature is only available in Concourse 5+.
    `prepare-image` does not work with Concourse 4.

=== "Task"
    ---excerpt--- "tasks/prepare-image"
=== "Implementation"
    ---excerpt--- "tasks/prepare-image-script"
=== "Usage"
    ---excerpt--- "reference/prepare-image-usage"

### prepare-tasks-with-secrets
Modifies task files to include variables needed for config files as environment variables
for run-time interpolation from a secret store.
Learn more about [secrets handling][secrets-handling].

!!! warn "Concourse 5+ Only"
    This task uses a Concourse feature
    that allows inputs and outputs to have the same name.
    This feature is only available in Concourse 5+.
    `prepare-tasks-with-secets` does not work with Concourse 4.

=== "Task"
    ---excerpt--- "tasks/prepare-tasks-with-secrets"
=== "Implementation"
    ---excerpt--- "tasks/prepare-tasks-with-secrets-script"
=== "Usage"
    ---excerpt--- "reference/prepare-tasks-with-secrets-usage"

### replicate-product
Will replicate the product for use in isolation segments.
The task requires a downloaded product prior to replication.
The output is a replicated tile with a new name in the metadata and filename.

!!! info "Using replicate-product"
    This command does not support storing the replicated product
    in a non-versioned blobstore, because it cannot generate a unique name.
    It is recommended to use the replicated tile immediately in the next task
    rather than storing it and using it in a different job.

=== "Task"
    ---excerpt--- "tasks/replicate-product"
=== "Implementation"
    ---excerpt--- "tasks/replicate-product-script"
=== "Usage"
    ---excerpt--- "examples/replicate-product-usage"

### revert-staged-changes
Reverts all changes that are currently staged on the Ops Manager.
This is only available _for_ Ops Manager 2.5.21+, 2.6.13+, or 2.7.2+

!!! warning "Using revert-staged-changes"
    Since this reverts all changes on an Ops Manager,
    it can conflict with tasks that perform stage or configure operations.
    Use passed constraints to ensure things run in the order you mean them to.

=== "Task"
    ---excerpt--- "tasks/revert-staged-changes"
=== "Implementation"
    ---excerpt--- "tasks/revert-staged-changes-script"
=== "Usage"
    ---excerpt--- "reference/revert-staged-changes-usage"

### send-telemetry
Sends the `.tar` output from [`collect-telemetry`][collect-telemetry]
to VMware.

!!! info Telemetry Key
    In order to use this task,
    you will need to acquire a license key.
    Contact your VMware Representative.

=== "Task"
    ---excerpt--- "tasks/send-telemetry"
=== "Implementation"
    ---excerpt--- "tasks/send-telemetry-script"
=== "Usage"
    ---excerpt--- "reference/send-telemetry-usage"

### stage-configure-apply
This is an _advanced task_.
Stage a product to Ops Manager, configure that product, and apply changes
only to that product without applying changes to the rest of the foundation.

{% include '.disable-verifiers.md' %}

=== "Task"
    ---excerpt--- "tasks/stage-configure-apply"
=== "Implementation"
    ---excerpt--- "tasks/stage-configure-apply-script"
=== "Usage"
    ---excerpt--- "examples/stage-configure-apply-usage"

### stage-product
Staged a product to the Ops Manager specified in the config file.

=== "Task"
    ---excerpt--- "tasks/stage-product"
=== "Implementation"
    ---excerpt--- "tasks/stage-product-script"
=== "Usage"
    ---excerpt--- "reference/stage-product-usage"

### staged-config
Downloads the configuration for a product from Ops Manager.

Not to be confused with Ops Manager's
built-in [export][bbr-export],
which puts all deployed products and configurations into a single file,
intended for import as part of backup/restore and upgrade lifecycle processes.

=== "Task"
    ---excerpt--- "tasks/staged-config"
=== "Implementation"
    ---excerpt--- "tasks/staged-config-script"
=== "Usage"
    ---excerpt--- "examples/staged-config-usage"

### staged-director-config

{% include "./.opsman_filename_change_note.md" %}

Downloads configuration for the BOSH director from Ops Manager.

=== "Task"
    ---excerpt--- "tasks/staged-director-config"
=== "Implementation"
    ---excerpt--- "tasks/staged-director-config-script"
=== "Usage"
    ---excerpt--- "examples/staged-director-config-usage"

The configuration is exported to the `generated-config` output.
It does not extract credentials from Ops Manager
and replaced them all with YAML interpolation `(())` placeholders.
This is to ensure that credentials are never written to disk.
The credentials need to be provided from an external configuration when invoking [configure-director](#configure-director).

{% include ".missing_fields_opsman_director.md" %}

### test
An example task to ensure the assets and docker image are setup correctly in your concourse pipeline.

=== "Task"
    ---excerpt--- "tasks/test"
=== "Implementation"
    ---excerpt--- "tasks/test-script"
=== "Usage"
    ---excerpt--- "reference/test-usage"

### test-interpolate
An example task to ensure that all required vars are present when interpolating into a base file.
For more instruction on this topic, see the [variables](concepts/variables.md) section

=== "Task"
    ---excerpt--- "tasks/test-interpolate"
=== "Implementation"
    ---excerpt--- "tasks/test-interpolate-script"
=== "Usage"
    ---excerpt--- "reference/test-interpolate-usage"

### update-runtime-config
This is an _advanced task_.
Updates a runtime config on the Ops Manager deployed BOSH director.
The task will interact with the BOSH director (sometimes via SSH tunnel through the Ops Manager),
upload BOSH releases,
and set a named runtime config.
This is useful when installing agents on BOSH deployed VMs that don't have a Ops Manager tile.

=== "Task"
    ---excerpt--- "tasks/update-runtime-config"
=== "Implementation"
    ---excerpt--- "tasks/update-runtime-config-script"
=== "Usage"
    ---excerpt--- "examples/update-runtime-config-usage"

!!! warn
    When using runtime configs, Ops Manager _owns_ the default runtime config.
    If you use this task to edit "default" it will be replaced on every Apply Changes.
    Please use `NAME` param to provide a non-conflicting runtime config.

### upgrade-opsman
Upgrades an existing Ops Manager to a new given Ops Manager version

=== "Task"
    ---excerpt--- "tasks/upgrade-opsman"
=== "Implementation"
    ---excerpt--- "tasks/upgrade-opsman-script"
=== "Usage"
    ---excerpt--- "reference/upgrade-opsman-usage"

For more information about this task and how it works, see the [upgrade](concepts/upgrade.md) page.

### upload-and-stage-product
Uploads and stages product to the Ops Manager specified in the config file.

=== "Task"
    ---excerpt--- "tasks/upload-and-stage-product"
=== "Implementation"
    ---excerpt--- "tasks/upload-and-stage-product-script"
=== "Usage"
    ---excerpt--- "reference/upload-and-stage-product-usage"

### upload-product
Uploads a product to the Ops Manager specified in the config file.

If a shasum is provided in the config.yml,
the integrity product will be verified
with that shasum before uploading.

=== "Task"
    ---excerpt--- "tasks/upload-product"
=== "Implementation"
    ---excerpt--- "tasks/upload-product-script"
=== "Usage"
    ---excerpt--- "reference/upload-product-usage"

### upload-stemcell
Uploads a stemcell to Ops Manager.

Note that the filename of the stemcell must be exactly as downloaded from Tanzu Network.
Ops Manager parses this filename to determine the version and OS of the stemcell.

=== "Task"
    ---excerpt--- "tasks/upload-stemcell"
=== "Implementation"
    ---excerpt--- "tasks/upload-stemcell-script"
=== "Usage"
    ---excerpt--- "reference/upload-stemcell-usage"

{% include ".internal_link_url.md" %}
{% include ".external_link_url.md" %}
