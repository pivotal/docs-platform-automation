---
title: Release Notes
owner: PCF Platform Automation
---

{% include "./.opsman_filename_change_note.md" %}

!!! warning "Azure Updating to 2.5"
     Ops Manager will be removing the necessity to provide availability zones for azure.
     If your `director.yml`(see [`staged-director-config`](./reference/task.md#staged-director-config))
     has a block like the following in the networks section:
     ```
        availability_zone_names:
        - "null"
     ```
     your deployment will have the following error:
     ```
     {"errors":["Availability zones cannot find availability zone with name null"]}
     ```
     To fix this error, please remove the `availability_zone_names` section from your azure config, or re-run
     [`staged-director-config`](./reference/task.md#staged-director-config) to update your `director.yml`.

These are release notes for Platform Automation for PCF.

## v2.2.1-beta.1
**Release Date** SomeDayOfTheWeek, Month, Day, Year

### What's New
TBD

### Bug Fixes
- in [gcp](./reference/inputs-outputs.md#gcp), if you did not assign a public IP, Google would assign
  one for you. This has been changed to only assign a public IP if defined in your `opsman.yml`.

## v2.2.0-beta.1
**Release Date** Thursday, March 14, 2019

### What's New
- New task [download-product-s3](./reference/task.md#download-product-s3)
  allows the version-specified download of products from S3.
  It consumes the same configuration file
  as the existing download-product task,
  with the addition of new S3-specific keys.
  If a `stemcell_iaas` is specified, it will also attempt to download the stemcell
  for the tile from an S3 bucket.
  For details, see the [Tasks reference](./reference/task.md#download-product-s3)
  and the [Inputs/Outputs reference](./reference/inputs-outputs.md#download-product-config).
- The reference pipeline has been updated to download the products directly from s3 now.
  The example config files used in the reference pipeline reflect these changes.
- When creating a OpsMan on Openstack, the option for `user_domain_name` has been added.
  This allows authenticating users on different domains of the Openstack deployment.
- [`staged-config`](./reference/task.md#staged-config) will now return `selected_option` for selectors. This means
  that the returned config will filter the selector appropriately and return the correct selected value.
  When using [`configure-product`](./reference/task.md#configure-product), users can now define either
  `option_value` or `selected_option` as the machine readable value for the selector, and the product will set the
  config appropriately in Ops Manager.
  Broadly, `staged-config` now works with selectors without any extra steps.
- [`staged-director-config`](./reference/task.md#staged-director-config) will now return placeholders
  for all secret/private fields in Ops Manager.
  Previously, not all such fields were returned from Ops Manager,
  so some secrets on some IaaSs were missing.
  They should all be there now.
- [download-product](./reference/task.md#download-product) now supports the authentication method of `iam` if it is 
  available. This will use an instance iam account rather than using access-key/secret-key
- [aws](./reference/inputs-outputs.md#aws) now supports using 
  [Instance Profiles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html) 
  as a means of authentication. If using `download-product`, consider setting `s3-auth-method: iam` in your 
  [download-product-config](./reference/inputs-outputs.md#download-product-config)

### Bug fixes
- There was a bug in `download-product` that would not quote the stemcell string in
  `assign-stemcell-config/config.yml`. This caused `assign-stemcell` to drop the trailing zero
  when attempting to assign a stemcell to a product. We fixed this.
- CVE update to container image. Resolves [USN-3891-1](https://usn.ubuntu.com/3891-1/)
  (related to vulnerabilities with `libsystemd0` and `systemd`.)
- CVE update to container image. Resolves [USN-3885-1](https://usn.ubuntu.com/3885-1/)
  (related to vulnerabilities with `openssh`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-3885-2](https://usn.ubuntu.com/3885-2/)
  (related to vulnerabilities with `openssh-client`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-3899-1](https://usn.ubuntu.com/3899-1/)
  (related to vulnerabilities with `libssl`. While none of our code directly used these,
  they are present on the image.)
- Fixed an issue with how `p-automator` matched file versions. This should not have affected any users.
  The issue was our regex matched the last two digits of a version, and with the update of semver-compatible
  versioning, this would technically be incorrect (even if unlikely).
- GCP will now use the global bucket for retrieving the Ops Manager image. This should give support back to non-US 
  regions when creating a vm.

## v2.1.1-beta.1

**Release Date** Thursday, February 7, 2019

### Bug Fixes
- CVE update to container image. Resolves [USN-3882-1](https://usn.ubuntu.com/3882-1/)
  (This related to vulnerabilities with `curl` and `libcurl`.
  While none of our code directly used these,
  they are present on the image.)

## v2.1.0-beta.1

**Release Date** Thursday January 31, 2019

### What's New
- [`create-vm`](./reference/task.md#create-vm) for vsphere now supports the configuration of memory in MB and number of CPUs.
  To configure these new properties, add the `memory` and/or `cpu` field to your [`opsman.yml`](./reference/inputs-outputs.md#vsphere).
  The defaults for these properties are the OVA defaults `memory: 8192` and `cpu: 1`.
- [`create-vm`](./reference/task.md#create-vm) for vsphere now gives a default vm_name of `Ops_Manager`
  if `vm_name` is not defined in your [`opsman.yml`](./reference/inputs-outputs.md#vsphere).

### Bug Fixes
- [`download-product`](./reference/task.md#download-product) did not pass `vars-files` correctly to all `interpolation` invocations.

## v2.0.0-beta.1

**Release Date** Wednesday January 30, 2018

### Breaking Changes
- [`configure-director`](./reference/task.md#configure-director) and [`staged-director-config`](./reference/task.md#staged-director-config) both have a new configuration definition.
  The new format can be found in [inputs](./reference/inputs-outputs.md#director-config).

    The following keys have recently been removed from the top level configuration: director-configuration, iaas-configuration, security-configuration, syslog-configuration.

    To fix this error, move the above keys under 'properties-configuration' and change their dashes to underscores.

    The old configuration file would contain the keys at the top level.

    ```yaml
    director-configuration: {}
    iaas-configuration: {}
    network-assignment: {}
    networks-configuration: {}
    resource-configuration: {}
    security-configuration: {}
    syslog-configuration: {}
    vmextensions-configuration: []
    ```

    They'll need to be moved to the new 'properties-configuration', with their dashes turn to underscore.
    For example, 'director-configuration' becomes 'director_configuration'.
    The new configration file will look like.

    ```yaml
    az-configuration: {}
    network-assignment: {}
    networks-configuration: {}
    properties-configuration:
      director_configuration: {}
      security_configuration: {}
      syslog_configuration: {}
      iaas_configuration: {}
      dns_configuration: {}
    resource-configuration: {}
    vmextensions-configuration: []
    ```

  This allows the format to be more stable
  and cross-version-compatible in the future.


### What's New
- [`download-product`](./reference/task.md#download-product) now supports `pas-windows`!
  The task will now automatically inject the needed Windows filesystem,
  meaning it's no longer necessary to run the `winfs-injector` separately.
  If you're on vSphere, note that the stemcell still needs to be built manually.
- [`export-installation`](./reference/task.md#export-installation) can now have a incrementing number added to the
  filename. This enables the `installation.zip` to be used on blob stores that don't support s3-like versioned files.
  This feature is enable by adding the `$timestamp` placeholder in the `INSTALLATION_FILE` param. For example,
  `INSTALLATION_FILE: installation-$timestamp.zip` will yield a file with the name `installation-20120620.1230.00+00.zip`,
  which is semver compatible timestamp.
- [`upgrade-opsman`](./reference/task.md#upgrade-opsman) has added more comprehensive validation around the required
  installation file. The task will now require that the installation provided match the expected exported installation
  format internally.

### Bug Fixes
- [`import-installation`](./reference/task.md#import-installation) always failed
  if an installation had a custom SSL cert;
  it now allows for the momentary API downtime from restarting nginx on Ops Manager
  after configuring the custom cert.

## v1.1.0-beta.1

**Release Date** Monday January 9, 2018

### What's New
- the [`bosh-cli`](https://bosh.io/docs/cli-v2/) is now included in the docker image.
- Large files now have retry logic in `om` to help prevent timeouts during upload.
- Azure now has support for unmanaged disks. By default, `p-automator` will use
  managed disks. To use an unmanaged disk, set `use_unmanaged_disk` to `true` in
  your [`opsman.yml`](./reference/inputs-outputs.md#azure)
- The reference pipeline now includes an example of how to use credhub interpolate
- GCP defaults have been changed to match Pivotal
  [recommendations](https://docs.pivotal.io/pivotalcf/2-4/om/gcp/deploy-manual.html#start-vm)
- The following params were added as optional arguments to the [OpenStack
  opsman configuration](./reference/inputs-outputs.md#openstack): `project_domain_name`,
  `identity_api_version`,`insecure`,`availability_zone`
- [Download Product](./reference/inputs-outputs.md#download-product-config) will now
  accept a regex for the product version


### Bug Fixes
- The `staged-config` task had another typo that made
  `SUSTITUTE_CREDENTIALS_WITH_PLACEHOLDERS` unusable.
  This has been corrected
- `staged-config` is now able to work with runtime-configs (e.g. NSX-T plugin)

## v1.0.1-beta.1

**Release Date** Monday December 17, 2018

### Bug Fixes
- The ability to use our image with Docker broke in 1.0.0.
  We had changed the details of how we construct our image,
  and this was an unintended side-effect.
  `docker import` works again now. Sorry!
- There was a new task to make git commits
  in the previous release, but it wasn't in the release notes.
  We've gone back and added it.
- The previously-unnanounced git-commit task didn't work!
  The git cli wasn't respecting the env vars
  used to configure author name and email,
  so we had to change to explicitly configuring it.
  Maybe it's for the best we didn't announce it.
  Now, it works.

## v1.0.0-beta.1

**Release Date:** December 5, 2018  

### What's New
* This product is now [semantically versioned](./compatibility-and-versioning.md#semantic-versioning)!
  We know there are a lot of breaking changes in this release.
  In the future, we'll try and keep that to a minimum -
  but we'll also communicate the presence of breaking changes
  with a major version bump.
* We've made major improvements and additions to our documentation.
  If you would like to give us feedback,
  open an issue on the github repo.
* Documentation is now versioned.
  If you would like to have a sneak peek on what we will be releasing next,
  check out the `develop` version of the documentation.
* Feature: tasks that configure the director or stage/configure a product
  will now fail if Ops Manager is Applying Changes.
  Previously, they would "succeed,"
  but when Ops Manager _finished_ Applying Changes,
  it would wipe out all the changes made by the "successful" tasks,
  which could lead to green pipelines that didn't _do_ anything.
  Ops Manager itself will enforce this restriction at some point in the future.
* [New Task](./reference/task.md#configure-ldap-authentication)
  LDAP authentication configuration is now supported.
* [New Task](./reference/task.md#assign-stemcell)
  This task will support the `floating-stemcell=false` workflow
  previously supported by `om`.
  To see if this workflow is right for you,
  please reference the [Stemcell Handling](./pipeline-design/stemcell-handling.md)
  section of the documentation.
* [New Task](./reference/task.md#upload-product)
  Upload product is now available independently from upload-and-stage-product.
* [New Task](./reference/task.md#stage-product)
  Stage product is now available independently from upload-and-stage-product.
* [New Task](./reference/task.md#make-git-commit)
  The code to make git commits was previously hidden away in our example pipeline.
  We've extracted it into its own task.
  This should be useful for persisting state files
  and downloaded configs with git.

### Breaking Changes
- Fix: the `staged-config` task had a lamentable typo, which we have now corrected.
  We had `SUBSTITUE_CREDENTIALS_WITH_PLACEHOLDERS`
  (note the missing third T in "substitute") when we meant (and now have)
  `SUBSTITUTE_CREDENTIALS_WITH_PLACEHOLDERS`.

!!! warning
    Any uses of `staged-config` in your pipelines will need to be updated
    if you were using the `SUBSTITUE_CREDENTIALS_WITH_PLACEHOLDERS` param.

- Feature: `configure-product` now fails if your configuration is incomplete.
  Previously, it would turn green, and you wouldn't learn of incomplete configuration
  until `apply-changes` failed.
  If you were intentionally using partial configurations,
  that won't work anymore.
  If you'd like to keep doing this,
  please contact your Pivotal representative
  and explain what you're trying to accomplish
  so we can make sure your use case gets covered.
- Feature: multi-resource group configurations now supported on Azure.
  The `vpc_network` property has been removed in Azure Ops Manager config,
  as it can be entirely determined from the `vpc_subnet` property.
  `vpc_subnet` now requires the resource id instead of its name.
  The format _must_ now match the following:
  `/subscriptions/<MY_SUBSCRIPTION_ID>/resourceGroups/<MY_RESOURCE_GROUP>/providers/Microsoft.Network/virtualNetworks/<MY_VNET>/subnets/<MY_SUBNET>`.
  This matches the terraforming-azure output `management_subnet_id`.
  This has been reflected in the [opsman.yml](./reference/inputs-outputs.md#azure) for Azure.
- Feature: if a configuration file for `configure-product` or `upgrade-vm` has a key that is unrecognized,
  the task will now fail and alert you as to which key is incorrect.
  As an example, if you accidentally use `product_properties` instead of `product-properties`,
  the task will now fail.


### Bug Fixes
We fixed several distinct errors around VM state and management
based on user feedback. Thanks for the bug reports!

* `upgrade-opsman` used to fail in vsphere
   when the VM was powered off.
   Now, it just deletes it and moves on.
*  we improved the error message on vSphere when the VM specified
   in the config file cannot be found.
*  we improved timeouts in the underlying `om` tool.
   Tasks that previously hung for a half hour by default
   in the event that the Ops Manager VM was unreachable
   will now fail in a few seconds, instead.
* `upgrade-opsman` on GCP used to fail
  when used on VMs not created by our tooling.
  It would fail to delete the image it expected
  as a result of our `create-vm` workflow.
  This task will now only report the absence of the expected image,
  and continue with the upgrade process.
* `delete-vm` would sometimes fail on AWS if the VM was already terminated.
  AWS cleans up terminated VMs eventually,
  so we just leave it alone.


!!! warning
    URLs for docs have changed.
    Please note that any saved/bookmarked links
    for specific pages in our documentation may no longer work.

## v0.0.1-rc248

**Release Date:** November 6, 2018

### What's New
* Documentation engine has been changed to mkdocs. Please give us feedback on the [new documentation](https://docs.pivotal.io/platform-automation/alpha/index.html)!
* [New Task](./reference/task.md#credhub-interpolate)
  Credhub interpolation is now supported by the tasks
* [New Task](./reference/task.md#download-product)
  A product can now be downloaded directly from pivnet. This task will also download the latest stemcell available
  for that tile and both will be provided as outputs for following tasks.
* `om` and `p-automator` are now fully separate CLIs. `om` is responsible for interacting with Ops Manager, and
  `p-automator` is responsible for interacting with the IaaS to manage the Ops Manager VM.
* `public_ssh_key` is now a configurable key for [vsphere](https://docs.pivotal.io/platform-automation/platform-automation/alpha/task-reference.html#public_ssh_key)
* The reference pipeline now has an example to apply changes after an upgrade of Ops Manager.

### Bug Fixes
* `om configure-product` used to fail with tiles featuring collections without `name` properties.
  It doesn't fail any more. However, users should be aware that in non-named collections,
  colliding collections may be overwritten, not updated, unless a guid is included in the config.
  This is of particular concern if the collection has state associated with it in the tile,
  as in the case of service plans. We are not aware of any service plan collections without a `name` field,
  but they may exist. Please file an issue in [om](https://github.com/pivotal-cf/om/issues/) if a problem occurs.
  See [om issue](https://github.com/pivotal-cf/om/issues/274) for the original bug report.

!!! warning
    URLs for docs will be changing in the next release. Please note that any saved/bookmarked links for specific pages in our documentation may not work in the future.  

## v0.0.1-rc229

**Release Date:** October 12, 2018

### What's New
* `p-automator -v` will return the version number of the release
* all tasks except `create-vm`, `delete-vm`, and `upgrade-opsman` are using `om`
* `om --env` now includes `decryption-passphrase` to automatically unlock the VM
  when performing a command on a rebooted VM

### Breaking Changes
* `import-installation` no longer takes an `auth.yml`, which used to contain `decryption-passphrase`.
  Now it is required to set the `decryption-passphrase` in the `env.yml` when using the task. See
  [env file](https://docs.pivotal.io/platform-automation/platform-automation/alpha/task-reference.html#env)
* `upgrade-opsman` invokes `import-installation` behind the scene, so the breaking change applies to this
  command as well. This mean that `upgrade-opsman` task no longer requires the `auth.yml`, but requires
  `decryption-passphrase` to be in the `env.yml`.

### Bug Fixes
* when specifying `STATE_FILE` it will only be used to identify the input.
  The `generated_state` will always just have `state.yml` for the output file name.

## v0.0.1-rc214

**Release Date:** October 9, 2018

### What's New
* the docker image is now both a concourse `garden-runc` and `docker import`able image
* added support to choose the Azure Cloud by setting `cloud_name` in your Ops Man VM config.
  The default is AzureCloud for the Americas. Other clouds can be found by running `az cloud list`.
* `om staged-config` now returns any vm-extensions set for a product
* `om configure-product` will now associate vm-extensions with a product


### Bug Fixes
* `create-vm`, `upgrade-opsman`, and `delete-vm`: Will output the correct `ipath` for VSphere created VMs.
  The pattern is `/datacenter/vm/folder/vm-name` if you would like to backfix your state file.
* `om staged-director-config` works with Azure Ops Man Vms as they don't have availability zones

## v0.0.1-rc194

**Release Date:** October 3, 2018

### What's New
* `create-vm`: Configurable instance type on AWS, see https://aws.amazon.com/ec2/instance-types/ for supported instance types.
* docker-image: Now shipping with docker image instead of self-service buildpack. See [Introduction][introduction]
* docker-image: Now shipping with docker image instead of self-service buildpack. See [Introduction][introduction]
  about how to use the image. It is based off the `cflinuxfs3` image.
* `staged-config` includes the errands and vm-extensions of the specified product

### Bug Fixes
* docs: `configure-saml-authentication`: Fix the top-level-keys of sample configuration
* `staged-config`: Change top-level-key from `product_name` to `product-name` to match the schema of `configure-product`
* show error message when `import-installation` fails during the `upgrade-opsman`

## v0.0.1-rc181

**Release Date:** September 27, 2018

### What's New
* `create-vm`: Shared VPC support for GCP. See [docs](reference/inputs-outputs.md#gcp) about the configuration.
* `create-vm`: Able to specify private IP for all supported IAASs (aws, azure, gcp, openstack, vsphere).
* `create-vm`: Able specify private IP and/or public IP. Only one is required to be set.
* `staged-config`: Able to pull errand config.
* `configure-director`: Able to configure bosh vm extensions

### Breaking Changes
* `staged-config`: flag change from `--include-placeholder` --> `--include-placeholders` (pluralize).
  The task has been updated and usage should be unaffected.

### Bug Fixes
* `configure-product`: Fix a non-deterministic behavior regarding collection type properties due to inconsistency in guid.
* `upgrade-opsman`: Fix a failure in argument parsing causing upgrade fails silently.

## v0.0.1-rc174

**Release Date:** September 21, 2018

Features included in this release:

* cleaning up resources in Azure, GCP, OpenStack when deleting the vm

* the latest `om` which includes the ability to specify `vm-extensions` key in the director config file.

* a script for building a Docker image

Breaking changes in this release:

* The auth resource has been split into two pieces, an `auth` file and an `env` file. The `auth` resource is now referred to as the `env` resource, and the `auth` file is now going to exist in the config resource. You can see how to create those inputs in the task reference of the documentation. This breaking changes effects existing rcs but should only involve changes to the pipeline.yml if you are using the new tasks.

## v0.0.1-rc146

**Release Date:** September 12, 2018

Features included in this release:

* update AWS to support private IP and/or public IP

* `staged-director-config` is now being invoked directly be `om` in the staged director task

## v0.0.1-rc138

**Release Date:** August 31, 2018

Features included in this release:

* Includes the latest `om` version

## v0.0.1-rc130

**Release Date:** August 22, 2018

Features included in this release:

* Includes the ability to do patch upgrades for OpsMan

## v0.0.1-rc123

**Release Date:** August 17, 2018

Features included in this release:

* First alpha release of Platform Automation for PCF

{% include ".internal_link_url.md" %}
