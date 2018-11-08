---
title: Release Notes
owner: PCF Platform Automation
---

These are release notes for Platform Automation for PCF.

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
* `public_ssh_key` is now a configurable key for [vsphere](https://docs.pivotal.io/pcf-automation/pcf-automation/alpha/task-reference.html#public_ssh_key)
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
  [env file](https://docs.pivotal.io/pcf-automation/pcf-automation/alpha/task-reference.html#env)
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
* docker-image: Now shipping with docker image instead of self-service buildpack. See [Getting-Started](getting-started.md)
  about how to use the image. It is based off the `cflinuxfs3` image.
* `staged-config` includes the errands and vm-extensions of the specified product

### Bug Fixes
* docs: `configure-saml-authentication`: Fix the top-level-keys of sample configuration
* `staged-config`: Change top-level-key from `product_name` to `product-name` to match the schema of `configure-product`
* show error message when `import-installation` fails during the `upgrade-opsman`

## v0.0.1-rc181

**Release Date:** September 27, 2018

### What's New
* `create-vm`: Shared VPC support for GCP. See [docs](reference/task.md#gcp) about the configuration.
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
