---
title: Release Notes
owner: PCF Platform Automation
---

These are release notes for Platform Automation for PCF.

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
* Documentation engine has been changed to mkdocs. Please give us feedback on the [new documentation](https://docs.pivotal.io/pcf-automation/alpha/index.html)!
* [New Task](./reference/task.md#credhub-interpolate)
  Credhub interpolation is now supported by the tasks
* [New Task](./reference/task.md#download-product)
  A product can now be downloaded directly from pivnet. This task will also download the latest stemcell available
  for that tile and both will be provided as outputs for following tasks.
* `om` and `p-automator` are now fully separate CLIs. `om` is responsible for interacting with Ops Manager, and
  `p-automator` is responsible for interacting with the IaaS to manage the Ops Manager VM.
* `public_ssh_key` is now a configurable key for [vsphere](https://docs.pivotal.io/pcf-automation/pcf-automation/v1.0/inputs-outputs.html#vsphere)
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
  [env file](https://docs.pivotal.io/pcf-automation/pcf-automation/v1.0/inputs-outputs.html#env)
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
{% include ".external_link_url.md" %}
