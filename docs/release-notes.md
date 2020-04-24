<style>
    .md-typeset h2 {
        font-weight: bold;
    }
</style>

{% include "./.opsman_filename_change_note.md" %}

!!! warning "Azure Updating to 2.5"
     Ops Manager will be removing the necessity to provide availability zones for azure.
     If your `director.yml`(see [`staged-director-config`][staged-director-config])
     has a block like the following in the networks section:
     ```yaml
        availability_zone_names:
        - "null"
     ```
     your deployment will have the following error:
     ```json
     {"errors":["Availability zones cannot find availability zone with name null"]}
     ```
     To fix this error, please remove the `availability_zone_names` section from your azure config, or re-run
     [`staged-director-config`][staged-director-config] to update your `director.yml`.

## Next Version
Coming Soon

| Name | version |
|---|---|
| om | [4.6.0](https://github.com/pivotal-cf/om/releases/tag/4.6.0) |
| bosh-cli | [6.2.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.2.1) |
| credhub | [2.6.2](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.2) |
| winfs-injector | [0.16.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.16.0) |

### What's New
- The [`stage-product`][stage-product] and [`stage-configure-apply`][stage-configure-apply] tasks
  have been updated to no longer require a `product` input.

    This change allows tiles to be staged without requiring the product file to be passed to these tasks.
    If the `product` input is not provided,
    the `PRODUCT_METADATA_NAME` and `PRODUCT_METADATA_VERSION` params **are required**.
    
- [`upgrade-opsman`][upgrade-opsman] now supports configuring settings
  on the Ops Manager Settings page in the UI. 
  This utilizes the `configure-opsman` command from `om`, 
  and runs after the upgrade command.
  Configuration can be added directly to [`opsman.yml`][inputs-outputs-configure-opsman].
  An example of all configurable properties can be found in the "Additional Settings" tab.

## v4.2.9
Pending Final Approval

| Name | version |
|---|---|
| om | [4.6.0](https://github.com/pivotal-cf/om/releases/tag/4.6.0) |
| bosh-cli | [6.2.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.2.1) |
| credhub | [2.6.2](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.2) |
| winfs-injector | [0.16.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.16.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4329-1](https://usn.ubuntu.com/4329-1/).
  This CVE is related to vulnerabilities with `git`.
- CVE update to container image. Resolves [USN-4334-1](https://usn.ubuntu.com/4334-1/).
  This CVE is related to vulnerabilities with `git`. 
- CVE update to container image. Resolves [USN-4333-1](https://usn.ubuntu.com/4333-1/).
  This CVE is related to vulnerabilities with `python`. 

## v4.2.8
Released April 24, 2020

| Name | version |
|---|---|
| om | [4.6.0](https://github.com/pivotal-cf/om/releases/tag/4.6.0) |
| bosh-cli | [6.2.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.2.1) |
| credhub | [2.6.2](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.2) |
| winfs-injector | [0.16.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.16.0) |

### Bug Fixes
- The `winfs-injector` has been bumped to support the new TAS Windows tile.
  When downloading a product from Pivnet, the [`download-product`][download-product] task
  uses `winfs-injector` to package the Windows rootfs in the tile.
  Newer version of TAS Windows, use a new packaging method, which requires this bump.
  
    If you see the following error, you need this fix.
  
    ```
    Checking if product needs winfs injected...+ '[' pas-windows == pas-windows ']'
    + '[' pivnet == pivnet ']'
    ++ basename downloaded-files/pas-windows-2.7.12-build.2.pivotal
    + TILE_FILENAME=pas-windows-2.7.12-build.2.pivotal
    + winfs-injector --input-tile downloaded-files/pas-windows-2.7.12-build.2.pivotal --output-tile downloaded-product/pas-windows-2.7.12-build.2.pivotal
    open /tmp/015434627/extracted-tile/embed/windowsfs-release/src/code.cloudfoundry.org/windows2016fs/2019/IMAGE_TAG: no such file or directory
    ``` 

## v4.2.7
Released March 25, 2020

| Name | version |
|---|---|
| om | [4.6.0](https://github.com/pivotal-cf/om/releases/tag/4.6.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.14.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.14.0) |

### Bug Fixes
- `configure-director` now correctly handles when you don't name your iaas_configuration `default` on vSphere.
  Previously, naming a configuration anything other than `default` would result in an extra, empty `default` configuration.
  This closes issue [#469](https://github.com/pivotal-cf/om/issues/469).
- Downloading a stemcell associated with a product will try to download the light or heavy stemcell.
  If anyone has experienced the recent issue with `download-product`
  and the AWS heavy stemcell,
  this will resolve your issue.
  Please remove any custom globbing that might've been added to circumvent this issue.
  For example, `stemcall-iaas: light*aws` should just be `stemcell-iaas: aws` now.
- Heavy stemcells could not be downloaded. 
  Support has now been added.
  Define `stemcell-heavy: true` in your `download-product` config file.
- CVE update to container image. Resolves [USN-4298-1](https://usn.ubuntu.com/4298-1/).
  This CVE is related to vulnerabilities with `libsqlite3`.
- CVE update to container image. Resolves [USN-4305-1](https://usn.ubuntu.com/4305-1/).
  This CVE is related to vulnerabilities with `libicu60`.

## v4.2.6
Released February 21, 2020

| Name | version |
|---|---|
| om | [4.3.0](https://github.com/pivotal-cf/om/releases/tag/4.3.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.14.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.14.0) |

### Bug Fixes
- GCP [`create-vm`][create-vm] now correctly handles an empty tags list
- CVE update to container image. Resolves [USN-4274-1](https://usn.ubuntu.com/4274-1/).
  The CVEs are related to vulnerabilities with `libxml2`.
- Bumped the following low-severity CVE packages: libsystemd0 libudev1

## v4.2.5
Released February 10, 2020

| Name | version |
|---|---|
| om | [4.3.0](https://github.com/pivotal-cf/om/releases/tag/4.3.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.14.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.14.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4243-1](https://usn.ubuntu.com/4243-1/).
  The CVEs are related to vulnerabilities with `libbsd`.
- CVE update to container image. Resolves [USN-4249-1](https://usn.ubuntu.com/4249-1/).
  The CVEs are related to vulnerabilities with `e2fsprogs`.
- CVE update to container image. Resolves [USN-4233-2](https://usn.ubuntu.com/4233-2/).
  The CVEs are related to vulnerabilities with `libgnutls30`.
- CVE update to container image. Resolves [USN-4256-1](https://usn.ubuntu.com/4256-1/).
  The CVEs are related to vulnerabilities with `libsasl2-2`.
- Bumped the following low-severity CVE packages: `libcom-err2`, `libext2fs2`, `libss2`, `linux-libc-dev`

## v4.2.4
Released January 28, 2020

| Name | version |
|---|---|
| om | [4.3.0](https://github.com/pivotal-cf/om/releases/tag/4.3.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.14.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.14.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4236-1](https://usn.ubuntu.com/4236-1/).
  The CVEs are related to vulnerabilities with `Libgcrypt`.
- CVE update to container image. Resolves [USN-4233-1](https://usn.ubuntu.com/4233-1/).
  The CVEs are related to vulnerabilities with `GnuTLS`.
- Bumped the following low-severity CVE package: `linux-libc-dev`

## v4.2.3
Released December 12, 2019

| Name | version |
|---|---|
| om | [4.3.0](https://github.com/pivotal-cf/om/releases/tag/4.3.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.14.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.14.0) |

### Bug Fixes
- When specifying `StorageSKU` for azure, `p-automator` would append `--storage-sku` twice in the creating VM invocation.
  It does not affect anything, but we removed the second instance to avoid confusion.
- CVE update to container image. Resolves [USN-4220-1](https://usn.ubuntu.com/4220-1/).
  The CVEs are related to vulnerabilities with `git`.
- Bumped the following low-severity CVE package: `linux-libc-dev`

## v4.2.2
Released December 3, 2019

| Name | version |
|---|---|
| om | [4.3.0](https://github.com/pivotal-cf/om/releases/tag/4.3.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.14.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.14.0) |

### What's New
- The `p-automator` CLI includes the ability to extract the Ops Manager VM configuration (GCP and AWS Only at the moment).
  This works for Ops Managers that are already running and useful when [migrating to automation][upgrade-how-to].

  Usage:

  1. Get the Platform Automation Toolkit image from Tanzu Network.
  1. Import that image into `docker` to run the [`p-automation` locally][running-commands-locally].
  1. Create a [state file][state] that represents your current VM and IAAS.
  1. Invoke the `p-automator` CLI to get the configuration.

  For example, on AWS with an access key and secret key:

  ```bash
  docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
    p-automator export-opsman-config \
    --state-file=state.yml \
    --aws-region=us-west-1 \
    --aws-secret-access-key some-secret-key \
    --aws-access-key-id some-access-key
  ```

  The outputted `opsman.yml` contains the information needed for Platform Automation Toolkit to manage the Ops Manager VM.

- When creating an `create-vm` task for Azure,
  the disk type and VM type can be specified.
  The configuration `storage_sku` and `vm_size` use the Azure values accordingly.
- The [`download-product`][download-product] task now supports the `SOURCE` param
  to specify where to download products and stemcells from.
  The supported sources are the Azure(`azure`), GCS(`gcs`), S3(`s3`), Tanzu Network(`pivnet`).
- [`configure-authentication`][configure-authentication],
  [`configure-ldap-authentication`][configure-ldap-authentication], and
  [`configure-saml-authentication`][configure-saml-authentication]
  now support passing through vars files to the underlying `om` command.
- When using [`configure-product`][configure-product] and [`configure-director`][configure-director],
  the `additional_vm_extensions` for a resource will have the following behaviour:
    - If not set in config file, the value from Ops Manager will be persisted.
    - If defined in the config file and an emtpy array (`[]`), the values on Ops Manager will be removed.
    - If defined in the file with a value (`["web_lb"]`), these values will be set on Ops Manager.
- When using [`configure-director`][configure-director]
  `vmextensions-configuration` can be defined to add|remove vm_extensions
  to|from the BOSH director. An example of this in the config:

    ```yaml
    vmextensions-configuration:
    - name: a_vm_extension
      cloud_properties:
        source_dest_check: false
    - name: another_vm_extension
      cloud_properties:
        foo: bar
    ```

### Deprecation Notices
- The [`download-product-s3`][download-product-s3] task has been deprecated
  in favor of the [`download-product`][download-product] task and setting the `SOURCE: s3` in `params`.

    For example, the `download-product-s3` in a pipeline:

    ```yaml
    - task: download-pas
      image: platform-automation-image
      file: platform-automation-tasks/tasks/download-product-s3.yml
      params:
        CONFIG_FILE: download-product/pas.yml
    ```

    Will be changed to:

    ```yaml
    - task: download-pas
      image: platform-automation-image
      file: platform-automation-tasks/tasks/download-product.yml
      params:
        CONFIG_FILE: download-product/pas.yml
        SOURCE: s3
    ```

### Bug Fixes
- When creating a Ops Manager on Azure,
  there was a bug in offline environments.
  We are now using the full image reference ID when creating the VM.  
- CVE update to container image. Resolves [USN-4205-1](https://usn.ubuntu.com/4205-1/).
  This CVE is related to vulnerabilities with `libsqlite3`.
  None of our code calls `libsqlite3` directly, but the IaaS CLIs rely on this package.

## v4.1.14
Pending Final Approval

| Name | version |
|---|---|
| om | [4.6.0](https://github.com/pivotal-cf/om/releases/tag/4.6.0) |
| bosh-cli | [6.2.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.2.1) |
| credhub | [2.6.2](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.2) |
| winfs-injector | [0.16.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.16.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4329-1](https://usn.ubuntu.com/4329-1/).
  This CVE is related to vulnerabilities with `git`.
- CVE update to container image. Resolves [USN-4334-1](https://usn.ubuntu.com/4334-1/).
  This CVE is related to vulnerabilities with `git`. 
- CVE update to container image. Resolves [USN-4333-1](https://usn.ubuntu.com/4333-1/).
  This CVE is related to vulnerabilities with `python`. 

## v4.1.13
Released April 20, 2020

| Name | version |
|---|---|
| om | [4.6.0](https://github.com/pivotal-cf/om/releases/tag/4.6.0) |
| bosh-cli | [6.2.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.2.1) |
| credhub | [2.6.2](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.2) |
| winfs-injector | [0.16.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.16.0) |

### Bug Fixes
- The `winfs-injector` has been bumped to support the new TAS Windows tile.
  When downloading a product from Pivnet, the [`download-product`][download-product] task
  uses `winfs-injector` to package the Windows rootfs in the tile.
  Newer version of TAS Windows, use a new packaging method, which requires this bump.
  
    If you see the following error, you need this fix.
  
    ```
    Checking if product needs winfs injected...+ '[' pas-windows == pas-windows ']'
    + '[' pivnet == pivnet ']'
    ++ basename downloaded-files/pas-windows-2.7.12-build.2.pivotal
    + TILE_FILENAME=pas-windows-2.7.12-build.2.pivotal
    + winfs-injector --input-tile downloaded-files/pas-windows-2.7.12-build.2.pivotal --output-tile downloaded-product/pas-windows-2.7.12-build.2.pivotal
    open /tmp/015434627/extracted-tile/embed/windowsfs-release/src/code.cloudfoundry.org/windows2016fs/2019/IMAGE_TAG: no such file or directory
    ``` 
 
## v4.1.12
Released March 25, 2020

| Name | version |
|---|---|
| om | [4.6.0](https://github.com/pivotal-cf/om/releases/tag/4.6.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.14.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.14.0) |

### Bug Fixes
- `configure-director` now correctly handles when you don't name your iaas_configuration `default` on vSphere.
  Previously, naming a configuration anything other than `default` would result in an extra, empty `default` configuration.
  This closes issue [#469](https://github.com/pivotal-cf/om/issues/469).
- Downloading a stemcell associated with a product will try to download the light or heavy stemcell.
  If anyone has experienced the recent issue with `download-product`
  and the AWS heavy stemcell,
  this will resolve your issue.
  Please remove any custom globbing that might've been added to circumvent this issue.
  For example, `stemcall-iaas: light*aws` should just be `stemcell-iaas: aws` now. 
- Heavy stemcells could not be downloaded. 
  Support has now been added.
  Define `stemcell-heavy: true` in your `download-product` config file.
- CVE update to container image. Resolves [USN-4298-1](https://usn.ubuntu.com/4298-1/).
  This CVE is related to vulnerabilities with `libsqlite3`.
- CVE update to container image. Resolves [USN-4305-1](https://usn.ubuntu.com/4305-1/).
  This CVE is related to vulnerabilities with `libicu60`.
   
## v4.1.11
Released February 25, 2020

| Name | version |
|---|---|
| om | [4.2.1](https://github.com/pivotal-cf/om/releases/tag/4.2.1) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- GCP [`create-vm`][create-vm] now correctly handles an empty tags list
- CVE update to container image. Resolves [USN-4274-1](https://usn.ubuntu.com/4274-1/).
  The CVEs are related to vulnerabilities with `libxml2`.
- Bumped the following low-severity CVE packages: libsystemd0 libudev1

## v4.1.10
Released February 7, 2020

| Name | version |
|---|---|
| om | [4.2.1](https://github.com/pivotal-cf/om/releases/tag/4.2.1) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4243-1](https://usn.ubuntu.com/4243-1/).
  The CVEs are related to vulnerabilities with `libbsd`.
- CVE update to container image. Resolves [USN-4249-1](https://usn.ubuntu.com/4249-1/).
  The CVEs are related to vulnerabilities with `e2fsprogs`.
- CVE update to container image. Resolves [USN-4233-2](https://usn.ubuntu.com/4233-2/).
  The CVEs are related to vulnerabilities with `libgnutls30`.
- CVE update to container image. Resolves [USN-4256-1](https://usn.ubuntu.com/4256-1/).
  The CVEs are related to vulnerabilities with `libsasl2-2`.
- Bumped the following low-severity CVE packages: `libcom-err2`, `libext2fs2`, `libss2`, `linux-libc-dev`

## v4.1.9
Released January 22, 2020

| Name | version |
|---|---|
| om | [4.2.1](https://github.com/pivotal-cf/om/releases/tag/4.2.1) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4236-1](https://usn.ubuntu.com/4236-1/).
  The CVEs are related to vulnerabilities with `Libgcrypt`.
- CVE update to container image. Resolves [USN-4233-1](https://usn.ubuntu.com/4233-1/).
  The CVEs are related to vulnerabilities with `GnuTLS`.

## v4.1.8
Released December 12, 2019

| Name | version |
|---|---|
| om | [4.2.1](https://github.com/pivotal-cf/om/releases/tag/4.2.1) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4220-1](https://usn.ubuntu.com/4220-1/).
  The CVEs are related to vulnerabilities with `git`.
- Bumped the following low-severity CVE package: `linux-libc-dev`

## v4.1.7
Released December 3, 2019

| Name | version |
|---|---|
| om | [4.2.1](https://github.com/pivotal-cf/om/releases/tag/4.2.1) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4205-1](https://usn.ubuntu.com/4205-1/).
  This CVE is related to vulnerabilities with `libsqlite3`.
  None of our code calls `libsqlite3` directly, but the IaaS CLIs rely on this package.
- When using the `check-pending-changes` task,
  it would not work because it reference a script that did not exist.
  The typo has been fixed and tested in the reference pipeline.
- Bumped the following low-severity CVE package: `linux-libc-dev`

## v4.1.5
Released November 19, 2019

| Name | version |
|---|---|
| om | [4.2.1](https://github.com/pivotal-cf/om/releases/tag/4.2.1) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4172-1](https://usn.ubuntu.com/4172-1/).
  This CVE is related to vulnerabilities with `file` and `libmagic`.
- CVE update to container image. Resolves [USN-4168-1](https://usn.ubuntu.com/4168-1/).
  This CVE is related to vulnerabilities with `libidn2`.
- Bump `bosh` CLI to v6.1.1
- Bump `credhub` CLI to v2.6.1

## v4.1.2
Released October 21, 2019

| Name | version |
|---|---|
| om | [4.1.0](https://github.com/pivotal-cf/om/releases/tag/4.1.0) |
| bosh-cli | [6.1.0](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.0) |
| credhub | [2.6.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.0) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### What's New
- [Ops Manager config for vSphere][inputs-outputs-vsphere] now validates the required properties
- The new task [expiring-certificates]
  fails if there are any expiring certificates
  in a user specified time range.
  Root CAs cannot be included in this list until Ops Manager 2.7.

  Example Output:

  ```text
  Getting expiring certificates...
  [X] Ops Manager
      cf-79fba6887e8c29375eb7:
          .uaa.service_provider_key_credentials: expired on 09 Aug 19 17:05 UTC
  could not execute "expiring-certificates": found expiring certs in the foundation
  exit status 1
  ```

- [Telemetry][telemetry-docs] support has been added!
  To opt in, you must get the Telemetry tool from [Tanzu Network][telemetry],
  create a [config file][telemetry-config],
  and add the [collect-telemetry][collect-telemetry] and [send-telemetry][send-telemetry] tasks to your pipeline.
  For an example, please see the [Reference Pipelines][reference-pipeline].
- [stage-configure-apply][stage-configure-apply] task has been added.
  This task will take a product, stage it, configure it, and apply changes
  _only_ for that product (all other products remain unchanged).
  Use this task only if you have confidence in the ordering
  in which you apply-changes for your products.
- [check-pending-changes][check-pending-changes] task has been added.
  This task will perform a check on Ops Manager and fail if there are pending changes.
  This is useful when trying to prevent manual changes
  from being applied during the automation process.
- The VM state files currently support YAML,
  but when generated, JSON was outputted.
  This caused confusion.
  The generated state file is now outputted as YAML.

### Deprecation Notices
- The `host` field in the vcenter section of the [vsphere opsman.yml][inputs-outputs-vsphere] has been deprecated.
  Platform Automation Toolkit can initially choose where the VM is placed
  but cannot guarantee that it stays there
  or that other generated VMs are assigned to the same host.
- The `vpc_subnet` field in [azure_opsman.yml][inputs-outputs-azure] has been deprecated.
  In your opsman.yml, replace `vpc_subnet` with `subnet_id`.
  This change was to help mitigate confusion
  as VPC is an AWS, not an Azure, concept.
- The optional `use_unmanaged_disk` field in [azure_opsman.yml][inputs-outputs-azure] has been deprecated.
  In your opsman.yml, replace `use_unmanaged_disk: true` with `use_managed_disk: false`.
  The default for `use_managed_disk` is true.
  Unmanaged disk is not recommended by Azure.
  If you would like to use unmanaged disks,
  please opt-out by setting `use_managed_disk: false`.
- The optional `use_instance_profile` field in [aws_opsman.yml][inputs-outputs-aws] has been deprecated.
  It was redundant.
  When you don't specify `access_key_id` and `secret_access_key`,
  the authentication will try to use the instance profile on the executing machine -- for example, a concourse worker.
  This is works in conjunction of how the `aws` CLI find authentication.
- The required `security_group_id` field in [aws_opsman.yml][inputs-outputs-aws] has been deprecated.
  Replace `security_group_id` with `security_group_ids` as YAML array.
  For example, `security_group_id: sg-1`
  becomes `security_group_ids: [ sg-1 ]`.
  This allows the specification of multiple security groups to the Ops Manager VM.

### Bug Fixes
- CVE update to container image. Resolves [USN-4151-1](https://usn.ubuntu.com/4151-1/).
  This CVE is related to vulnerabilities with `python`.
  None of our code calls `python` directly, but the IaaS CLIs rely on this package.

## v4.0.14
Pending Final Approval

| Name | version |
|---|---|
| om | [4.6.0](https://github.com/pivotal-cf/om/releases/tag/4.6.0) |
| bosh-cli | [6.2.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.2.1) |
| credhub | [2.6.2](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.2) |
| winfs-injector | [0.16.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.16.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4329-1](https://usn.ubuntu.com/4329-1/).
  This CVE is related to vulnerabilities with `git`.
- CVE update to container image. Resolves [USN-4334-1](https://usn.ubuntu.com/4334-1/).
  This CVE is related to vulnerabilities with `git`. 
- CVE update to container image. Resolves [USN-4333-1](https://usn.ubuntu.com/4333-1/).
  This CVE is related to vulnerabilities with `python`. 

## v4.0.13
Released April 20, 2020

| Name | version |
|---|---|
| om | [4.6.0](https://github.com/pivotal-cf/om/releases/tag/4.6.0) |
| bosh-cli | [6.2.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.2.1) |
| credhub | [2.6.2](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.2) |
| winfs-injector | [0.16.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.16.0) |

### Bug Fixes
- The `winfs-injector` has been bumped to support the new TAS Windows tile.
  When downloading a product from Pivnet, the [`download-product`][download-product] task
  uses `winfs-injector` to package the Windows rootfs in the tile.
  Newer version of TAS Windows, use a new packaging method, which requires this bump.
  
    If you see the following error, you need this fix.
  
    ```
    Checking if product needs winfs injected...+ '[' pas-windows == pas-windows ']'
    + '[' pivnet == pivnet ']'
    ++ basename downloaded-files/pas-windows-2.7.12-build.2.pivotal
    + TILE_FILENAME=pas-windows-2.7.12-build.2.pivotal
    + winfs-injector --input-tile downloaded-files/pas-windows-2.7.12-build.2.pivotal --output-tile downloaded-product/pas-windows-2.7.12-build.2.pivotal
    open /tmp/015434627/extracted-tile/embed/windowsfs-release/src/code.cloudfoundry.org/windows2016fs/2019/IMAGE_TAG: no such file or directory
    ``` 

## v4.0.12
Released March 25, 2020

| Name | version |
|---|---|
| om | [3.2.3](https://github.com/pivotal-cf/om/releases/tag/3.2.3) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.14.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.14.0) |

### Bug Fixes
- Downloading a stemcell associated with a product will try to download the light or heavy stemcell.
  If anyone has experienced the recent issue with `download-product`
  and the AWS heavy stemcell,
  this will resolve your issue.
  Please remove any custom globbing that might've been added to circumvent this issue.
  For example, `stemcall-iaas: light*aws` should just be `stemcell-iaas: aws` now. 
- CVE update to container image. Resolves [USN-4298-1](https://usn.ubuntu.com/4298-1/).
  This CVE is related to vulnerabilities with `libsqlite3`.
- CVE update to container image. Resolves [USN-4305-1](https://usn.ubuntu.com/4305-1/).
  This CVE is related to vulnerabilities with `libicu60`.
  
## v4.0.11
Released February 21, 2020

| Name | version |
|---|---|
| om | [3.1.0](https://github.com/pivotal-cf/om/releases/tag/3.1.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- GCP [`create-vm`][create-vm] now correctly handles an empty tags list
- CVE update to container image. Resolves [USN-4274-1](https://usn.ubuntu.com/4274-1/).
  The CVEs are related to vulnerabilities with `libxml2`.
- Bumped the following low-severity CVE packages: libsystemd0 libudev1

## v4.0.10
Released February 4, 2020

| Name | version |
|---|---|
| om | [3.1.0](https://github.com/pivotal-cf/om/releases/tag/3.1.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4243-1](https://usn.ubuntu.com/4243-1/).
  The CVEs are related to vulnerabilities with `libbsd`.
- CVE update to container image. Resolves [USN-4249-1](https://usn.ubuntu.com/4249-1/).
  The CVEs are related to vulnerabilities with `e2fsprogs`.
- CVE update to container image. Resolves [USN-4233-2](https://usn.ubuntu.com/4233-2/).
  The CVEs are related to vulnerabilities with `libgnutls30`.
- CVE update to container image. Resolves [USN-4256-1](https://usn.ubuntu.com/4256-1/).
  The CVEs are related to vulnerabilities with `libsasl2-2`.
- Bumped the following low-severity CVE packages: `libcom-err2`, `libext2fs2`, `libss2`, `linux-libc-dev`

## v4.0.9
Released January 22, 2020

| Name | version |
|---|---|
| om | [3.1.0](https://github.com/pivotal-cf/om/releases/tag/3.1.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4236-1](https://usn.ubuntu.com/4236-1/).
  The CVEs are related to vulnerabilities with `Libgcrypt`.
- CVE update to container image. Resolves [USN-4233-1](https://usn.ubuntu.com/4233-1/).
  The CVEs are related to vulnerabilities with `GnuTLS`.
- Bumped the following low-severity CVE package: `linux-libc-dev`

## v4.0.8
Released December 12, 2019

| Name | version |
|---|---|
| om | [3.1.0](https://github.com/pivotal-cf/om/releases/tag/3.1.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4220-1](https://usn.ubuntu.com/4220-1/).
  The CVEs are related to vulnerabilities with `git`.
- Bumped the following low-severity CVE package: `linux-libc-dev`

## v4.0.7
Released December 3, 2019

| Name | version |
|---|---|
| om | [3.1.0](https://github.com/pivotal-cf/om/releases/tag/3.1.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4205-1](https://usn.ubuntu.com/4205-1/).
  This CVE is related to vulnerabilities with `libsqlite3`.
  None of our code calls `libsqlite3` directly, but the IaaS CLIs rely on this package.

## v4.0.6
Released November 6, 2019

| Name | version |
|---|---|
| om | [3.1.0](https://github.com/pivotal-cf/om/releases/tag/3.1.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4172-1](https://usn.ubuntu.com/4172-1/).
  This CVE is related to vulnerabilities with `file` and `libmagic`.
- CVE update to container image. Resolves [USN-4168-1](https://usn.ubuntu.com/4168-1/).
  This CVE is related to vulnerabilities with `libidn2`.
- Bump `bosh` CLI to v6.1.1
- Bump `credhub` CLI to v2.6.1

## v4.0.5
Released October 25, 2019

| Name | version |
|---|---|
| om | [3.1.0](https://github.com/pivotal-cf/om/releases/tag/3.1.0) |
| bosh-cli | [5.5.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v5.5.1) |
| credhub | [2.5.2](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.5.2) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4151-1](https://usn.ubuntu.com/4151-1/).
  This CVE is related to vulnerabilities with `python`.
  None of our code calls `python` directly, but the IaaS CLIs rely on this package.  

## v4.0.4

Released October 15, 2019, includes `om` version [3.1.0](https://github.com/pivotal-cf/om/releases/tag/3.1.0)

### Bug Fixes
- CVE update to container image. Resolves [USN-4142-1](https://usn.ubuntu.com/4142-1/).
  (related to vulnerabilities with `e2fsprogs`. While none of our code directly used these,
  they are present on the image.)
- Bumped the following low-severity CVE packages: `libcom-err2`, `libext2fs2`, `libss2`, `linux-libc-dev`

## v4.0.3

Released September 27, 2019, includes `om` version [3.1.0](https://github.com/pivotal-cf/om/releases/tag/3.1.0)

### Bug Fixes
- CVE update to container image. Resolves [USN-4127-1](https://usn.ubuntu.com/4127-1/).
  This CVE is related to vulnerabilities with `python`.
  None of our code calls `python` directly, but the IaaS CLIs rely on this package.
- CVE update to container image. Resolves [USN-4129-1](https://usn.ubuntu.com/4129-1/).
  (related to vulnerabilities with `curl` and `libcurl`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-4132-1](https://usn.ubuntu.com/4132-1/).
  (related to vulnerabilities with `expat`. While none of our code directly used these,
  they are present on the image.)
- Bumped the following low-severity CVE packages: `libsystemd0`, `libudev1`, `linux-libc-dev`

## v4.0.1

Released September 4, 2019, includes `om` version [3.1.0](https://github.com/pivotal-cf/om/releases/tag/3.1.0)

### Bug Fixes
- CVE update to container image. Resolves [USN-4108-1](https://usn.ubuntu.com/4108-1/).
  (related to vulnerabilities with `libzstd`. While none of our code directly used these,
  they are present on the image.)
- Bumped the following low-severity CVE packages: `linux-libc-dev`

## v4.0.0

Released August 28, 2019, includes `om` version [3.1.0](https://github.com/pivotal-cf/om/releases/tag/3.1.0)

### Breaking Changes

- The tasks have been updated to extract their `bash` scripting into a separate script.
  The tasks' script can be used with different CI/CD systems like Jenkins.

  This will be a breaking change if your tasks resource is not named `platform-automation-tasks`.

  For example,

  ```yaml
  - get: tasks
  - task: configure-authentication
    file: tasks/tasks/configure-authentication.yml
  ```

  will be changed to

  ```yaml
  - get: platform-automation-tasks
  - task: configure-authentication
    file: platform-automation-tasks/tasks/configure-authentication.yml
  ```

  Notice that the resource name changed as did the relative path to the task YAML file in `file`.

### What's New
- [`configure-ldap-authentication`][configure-ldap-authentication], [`configure-saml-authentication`][configure-saml-authentication], and [`configure-authentication`][configure-authentication]
  can create a UAA client on the Ops Manager VM.
  The client_secret will be the value provided to this option `precreated-client-secret`.
  This is supported in OpsManager 2.5+.
- For Ops Manager 2.6+, new task [`pre-deploy-check`][pre-deploy-check]
  will validate that Ops Manager and it's staged products
  are configured correctly.
  This may be run at any time
  and may be used as a pre-check for `apply-changes`.
- For GCP, [`create-vm`][create-vm] will now allow you
  to specify a `gcp_service_account_name`
  for the new Ops Manager VM.
  This enables you to designate a service account name
  as opposed to providing a service account json object.
  This may be specified in the [Ops Manager config for GCP][inputs-outputs-gcp].
  For more information on GCP service accounts, refer to the [GCP service accounts][gcp-service-accounts] docs.
- For GCP, [`create-vm`][create-vm] supports setting `scopes` for the new Ops Manager VM.
  This may be specified in the [Ops Manager config for GCP][inputs-outputs-gcp].
  For more information on setting GCP scopes, refer to the [GCP scope][gcp-scope] docs.
- [`configure-director`][configure-director] now support [VM Extensions][vm-extensions].
  Please note this is an advanced feature, and should be used at your own discretion.  
- [`configure-director`][configure-director] now support [VM Types][vm-types].
  Please note this is an advanced feature, and should be used at your own discretion.
- Add support for new NSX and NSXT format in Ops Manager 2.7+
  when calling [`staged-config`][staged-config] and [`staged-director-config`][staged-director-config]
- [state][state] can now be defined in a `state-$timestamp.yml` format (like [`export-installation`][export-installation]).
  This is an _opt-in_ feature, and is only recommended
  if you are storing state in a non-versioned s3-compatible blobstore.
  To opt-in to this feature,
  a param must be added to your pipeline
  and given the value of `STATE_FILE: state-$timestamp.yml`
  for each invocation of the following commands:
      - [`create-vm`][create-vm]
      - [`delete-vm`][delete-vm]
      - [`upgrade-opsman`][upgrade-opsman]
- [gcp opsman.yml][inputs-outputs-gcp] now supports `ssh_public_key`.
  This is used to ssh into the Ops Manager VM to manage non-tile bosh add-ons.

### Bug Fixes
- [`download-product`][download-product] will now return a `download-product.json`
  if `stemcell-iaas` is defined, but there is no stemcell to download for that product.
- [vsphere opsman.yml][inputs-outputs-vsphere] now requires `ssh_public_key` for Ops Manager 2.6+
  This was added to mitigate an error during upgrade
  that would cause the VM to enter a reboot loop.
- When using AWS to create the Ops Manager VM with encrypted disks,
  the task [`create-vm`][create-vm] and [`upgrade-opsman`][upgrade-opsman] will wait for disk encryption to be completed.
  An exponential backoff will be and timeout after an hour if disk is not ready.

## v3.0.18
Released February 20, 2020

| Name | version |
|---|---|
| om | [3.0.0](https://github.com/pivotal-cf/om/releases/tag/3.0.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- GCP [`create-vm`][create-vm] now correctly handles an empty tags list
- CVE update to container image. Resolves [USN-4274-1](https://usn.ubuntu.com/4274-1/).
  The CVEs are related to vulnerabilities with `libxml2`.
- Bumped the following low-severity CVE packages: libsystemd0 libudev1

## v3.0.17
Released February 3, 2020

| Name | version |
|---|---|
| om | [3.0.0](https://github.com/pivotal-cf/om/releases/tag/3.0.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4243-1](https://usn.ubuntu.com/4243-1/).
  The CVEs are related to vulnerabilities with `libbsd`.
- CVE update to container image. Resolves [USN-4249-1](https://usn.ubuntu.com/4249-1/).
  The CVEs are related to vulnerabilities with `e2fsprogs`.
- CVE update to container image. Resolves [USN-4233-2](https://usn.ubuntu.com/4233-2/).
  The CVEs are related to vulnerabilities with `libgnutls30`.
- CVE update to container image. Resolves [USN-4256-1](https://usn.ubuntu.com/4256-1/).
  The CVEs are related to vulnerabilities with `libsasl2-2`.
- Bumped the following low-severity CVE packages: `libcom-err2`, `libext2fs2`, `libss2`, `linux-libc-dev`

## v3.0.16
Released January 28, 2020

| Name | version |
|---|---|
| om | [3.0.0](https://github.com/pivotal-cf/om/releases/tag/3.0.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4236-1](https://usn.ubuntu.com/4236-1/).
  The CVEs are related to vulnerabilities with `Libgcrypt`.
- CVE update to container image. Resolves [USN-4233-1](https://usn.ubuntu.com/4233-1/).
  The CVEs are related to vulnerabilities with `GnuTLS`.
- Bumped the following low-severity CVE package: `linux-libc-dev`

## v3.0.15
Released December 12, 2019

| Name | version |
|---|---|
| om | [3.0.0](https://github.com/pivotal-cf/om/releases/tag/3.0.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4220-1](https://usn.ubuntu.com/4220-1/).
  The CVEs are related to vulnerabilities with `git`.
- Bumped the following low-severity CVE package: `linux-libc-dev`

## v3.0.14
Released December 3, 2019

| Name | version |
|---|---|
| om | [3.0.0](https://github.com/pivotal-cf/om/releases/tag/3.0.0) |
| bosh-cli | [6.1.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.1.1) |
| credhub | [2.6.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.6.1) |
| winfs-injector | [0.13.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.13.0) |

### Bug Fixes
- CVE update to container image. Resolves [USN-4205-1](https://usn.ubuntu.com/4205-1/).
  This CVE is related to vulnerabilities with `libsqlite3`.
  None of our code calls `libsqlite3` directly, but the IaaS CLIs rely on this package.

## v3.0.13
Released November 14, 2019, includes `om` version [3.0.0](https://github.com/pivotal-cf/om/releases/tag/3.0.0)

### Bug Fixes
- CVE update to container image. Resolves [USN-4172-1](https://usn.ubuntu.com/4172-1/).
  This CVE is related to vulnerabilities with `file` and `libmagic`.
- CVE update to container image. Resolves [USN-4168-1](https://usn.ubuntu.com/4168-1/).
  This CVE is related to vulnerabilities with `libidn2`.
- Bump `bosh` CLI to v6.1.1
- Bump `credhub` CLI to v2.6.1

## v3.0.12
Released October 25, 2019, includes `om` version [3.0.0](https://github.com/pivotal-cf/om/releases/tag/3.0.0)

### Bug Fixes
- CVE update to container image. Resolves [USN-4151-1](https://usn.ubuntu.com/4151-1/).
  This CVE is related to vulnerabilities with `python`.
  None of our code calls `python` directly, but the IaaS CLIs rely on this package.

## v3.0.11

Released October 15, 2019, includes `om` version [3.0.0](https://github.com/pivotal-cf/om/releases/tag/3.0.0)

### Bug Fixes
- CVE update to container image. Resolves [USN-4142-1](https://usn.ubuntu.com/4142-1/).
  (related to vulnerabilities with `e2fsprogs`. While none of our code directly used these,
  they are present on the image.)
- Bumped the following low-severity CVE packages: `libcom-err2`, `libext2fs2`, `libss2`, `linux-libc-dev`

## v3.0.10
Released September 26, 2019, includes `om` version [3.0.0](https://github.com/pivotal-cf/om/releases/tag/3.0.0)

### Bug Fixes
- CVE update to container image. Resolves [USN-4127-1](https://usn.ubuntu.com/4127-1/).
  This CVE is related to vulnerabilities with `python`.
  None of our code calls `python` directly, but the IaaS CLIs rely on this package.
- CVE update to container image. Resolves [USN-4129-1](https://usn.ubuntu.com/4129-1/).
  (related to vulnerabilities with `curl` and `libcurl`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-4132-1](https://usn.ubuntu.com/4132-1/).
  (related to vulnerabilities with `expat`. While none of our code directly used these,
  they are present on the image.)
- Bumped the following low-severity CVE packages: `libsystemd0`, `libudev1`, `linux-libc-dev`

## v3.0.8
Released September 4, 2019, includes `om` version [3.0.0](https://github.com/pivotal-cf/om/releases/tag/3.0.0)

### Bug Fixes
- CVE update to container image. Resolves [USN-4108-1](https://usn.ubuntu.com/4108-1/).
  (related to vulnerabilities with `libzstd`. While none of our code directly used these,
  they are present on the image.)
- Bumped the following low-severity CVE packages:
  `libpython2.7`, `libpython2.7-dev`, `libpython2.7-minimal`, `libpython2.7-stdlib`, `libssl1.1`
  `openssl`, `python-cryptography`, `python2.7`, `python2.7-dev`, `python2.7-minimal`

## v3.0.7
Released August 28, 2019, includes `om` version [3.0.0](https://github.com/pivotal-cf/om/releases/tag/3.0.0)

### Bug Fixes
- When using AWS to create the Ops Manager VM with encrypted disks,
  the task [`create-vm`][create-vm] and [`upgrade-opsman`][upgrade-opsman] will wait for disk encryption to be completed.
  An exponential backoff will be and timeout after an hour if disk is not ready.
- CVE update to container image. Resolves [USN-4071-1](https://usn.ubuntu.com/4071-1/).
  (related to vulnerabilities with `patch`. While none of our code directly used these,
  they are present on the image.)
- Bumped the following low-severity CVE packages:
  `linux-libc-dev`, `libldap-2.4-2`, `libldap-common`, `linux-libc-dev`

## v3.0.5
Released July 22, 2019, includes `om` version [3.0.0](https://github.com/pivotal-cf/om/releases/tag/3.0.0)

### Bug Fixes
- in [`credhub-interpolate`][credhub-interpolate], [`upload-product`][upload-product], and [`upload-stemcell`][upload-stemcell]
  setting `SKIP_MISSING: false` the command would fail.
  This has been fixed.  
- [`upgrade-opsman`][upgrade-opsman] would fail on the [`import-installation`][import-installation] step
  if the env file did not contain a target or decryption passphrase.
  This will now fail before the upgrade process begins
  to ensure faster feedback.
- [`upgrade-opsman`][upgrade-opsman] now respects environment variables
  when it makes calls internally to `om`
  (env file still required).
- [`download-product-s3`][download-product-s3] does not require `pivnet-api-token` anymore.
- `om` CLI has been bumped to v3.0.0.
  This includes the following bug fixes:
    * `apply-changes --product <product>` will error with _product not found_ if that product has not been staged.
    * `upload-stemcell` now accepts `--floating false` in addition to `floating=false`.
      This was done to offer consistency between all of the flags on the command.
    * `skip-unchanged-products` was removed from `apply-changes`.
      This option has had issues with consistent successful behaviour.
      For example, if the apply changes fails for any reason, the subsequent apply changes cannot pick where it left off.
      This usually happens in the case of errands that are used for services.

        We are working on scoping a selective deploy feature that makes sense for users.
        We would love to have feedback from users about this.

    * remove `revert-staged-changes`
      `unstage-product` functionally does the same thing,
      but uses the API.
- Bumped the following low-severity CVE packages: `unzip`

## v3.0.4
Released July 11, 2019, includes `om` version [2.0.0](https://github.com/pivotal-cf/om/releases/tag/2.0.0)

### Bug Fixes
- Both [`configure-ldap-authentication`][configure-ldap-authentication]
  and [`configure-saml-authentication`][configure-saml-authentication]
  will now automatically
  create a BOSH UAA admin client as documented [here](https://docs.pivotal.io/pivotalcf/2-5/customizing/opsmanager-create-bosh-client.html#saml).
  This is only supported in OpsManager 2.4 and greater.
  You may specify the option `skip-create-bosh-admin-client` in your config YAML
  to skip creating this client.
  After the client has been created,
  you can find the client ID and secret
  by following [steps three and four found here](https://docs.pivotal.io/pivotalcf/2-5/customizing/opsmanager-create-bosh-client.html#-provision-admin-client).

    _This feature needs to be enabled
    to properly automate authentication for the bosh director when using LDAP and SAML._
    If `skip-create-bosh-admin-client: true` is specified, manual steps are required,
    and this task is no longer "automation".

- [`create-vm`][create-vm] and [`upgrade-opsman`][upgrade-opsman] now function with `gcp_service_account_name` on GCP.
  Previously, only providing a full `gcp_service_account` as a JSON blob worked.
- Environment variables passed to [`create-vm`][create-vm], [`delete-vm`][delete-vm], and [`upgrade-opsman`][upgrade-opsman]
  will be passed to the underlying IAAS CLI invocation.
  This allows our tasks to work with the `https_proxy` and `no_proxy` variables
  that can be [set in Concourse](https://github.com/concourse/concourse-bosh-release/blob/9764b66a6d85785735f6ea8ddcabf77785b5eddd/jobs/worker/spec#L50-L65).
- [`download-product`][download-product] task output of `assign-stemcell.yml` will have the correct `product-name`
- When using the `env.yml` for a task,
  extra values passed in the env file will now fail if they are not recognized properties.
  Invalid properties might now produce the following:
    ```bash
      $ om --env env.yml upload-product --product product.pivotal
      could not parse env file: yaml: unmarshal errors:
      line 5: field invalid-field not found in type main.options
    ```

- `credhub` CLI has been bumped to v2.5.1.
  This includes a fix of not raising an error when processing an empty YAML file.
- `om` CLI has been bumped to v2.0.0.
  This includes the following bug fixes:
    * `download-product` will now return a `download-file.json`
      if `stemcell-iaas` is defined but the product has no stemcell.
      Previously, this would exit gracefully, but not return a file.
    * Non-string environment variables can now be read and passed as strings to Ops Manager.
      For example, if your environment variable (`OM_NAME`) is set to `"123"` (with quotes escaped),
      it will be evaluated in your config file with the quotes.

        Given `config.yml`
        ```yaml
        value: ((NAME))
        ```

        `om interpolate -c config.yml --vars-env OM`

        Will evaluate to:
        ```yaml
          value: "123"
        ```

    * `bosh-env` will now set `BOSH_ALL_PROXY` without a trailing slash if one is provided
    * When using `bosh-env`, a check is done to ensure the SSH private key exists.
      If does not the command will exit 1.
    * `config-template` will enforce the default value for a property to always be `configurable: false`.
      This is inline with the OpsManager behaviour.

- CVE update to container image. Resolves [USN-4040-1](https://usn.ubuntu.com/4040-1/).
  (related to vulnerabilities with `Expat`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-4038-1](https://usn.ubuntu.com/4038-1/) and [USN-4038-3](https://usn.ubuntu.com/4038-3/).
  (related to vulnerabilities with `bzip`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-4019-1](https://usn.ubuntu.com/4019-1/).
  (related to vulnerabilities with `SQLite`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [CVE-2019-11477](https://people.canonical.com/~ubuntu-security/cve/2019/CVE-2019-11477.html).
  (related to vulnerabilities with `linux-libc-dev`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-4049-1](https://usn.ubuntu.com/4049-1/).
  (related to vulnerabilities with `libglib`. While none of our code directly used these,
  they are present on the image.)

## v3.0.2
Released July 8, 2019, includes `om` version [1.0.0](https://github.com/pivotal-cf/om/releases/tag/1.0.0)

### Bug Fixes
- CVE update to container image. Resolves [USN-4014-1](https://usn.ubuntu.com/4014-1/).
  (related to vulnerabilities with `GLib`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-4015-1](https://usn.ubuntu.com/4015-1/).
  (related to vulnerabilities with `DBus`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-3999-1](https://usn.ubuntu.com/3999-1/).
  (related to vulnerabilities with `GnuTLS`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-4001-1](https://usn.ubuntu.com/4001-1/).
  (related to vulnerabilities with `libseccomp`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-4004-1](https://usn.ubuntu.com/4004-1/).
  (related to vulnerabilities with `Berkeley DB`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-3993-1](https://usn.ubuntu.com/3993-1/).
  (related to vulnerabilities with `curl`. While none of our code directly used these,
  they are present on the image.)

## v3.0.1
Released May 24, 2019, includes `om` version [1.0.0](https://github.com/pivotal-cf/om/releases/tag/1.0.0)

### Breaking Changes
- `om` will now follow conventional Semantic Versioning,
  with breaking changes in major bumps,
  non-breaking changes for minor bumps,
  and bug fixes for patches.
- The [`credhub-interpolate`][credhub-interpolate] task can have multiple
  interpolation paths. The `INTERPOLATION_PATH` param is now plural: `INTERPOLATION_PATHS`.
  IF you are using a custom `INTERPOLATION_PATH` for `credhub-interpolate`, you will need to update
  your `pipeline.yml` to this new param.
  As an example, if your credhub-interpolate job is defined as so:
```yaml
# OLD pipeline.yml PRIOR TO 3.0.0 RELEASE
- name: example-credhub-interpolate
  plan:
  - get: platform-automation-tasks
  - get: platform-automation-image
  - get: config
  - task: credhub-interpolate
    image: platform-automation-image
    file: platform-automation-tasks/tasks/credhub-interpolate.yml
    input_mapping:
      files: config
    params:
      # all required
      CREDHUB_CA_CERT: ((credhub_ca_cert))
      CREDHUB_CLIENT: ((credhub_client))
      CREDHUB_SECRET: ((credhub_secret))
      CREDHUB_SERVER: ((credhub_server))
      PREFIX: /private-foundation
      INTERPOLATION_PATH: foundation/config-path
      SKIP_MISSING: true
```
  it should now look like
```yaml hl_lines="19"
# NEW pipeline.yml FOR 3.0.0 RELEASE
- name: example-credhub-interpolate
  plan:
  - get: platform-automation-tasks
  - get: platform-automation-image
  - get: config
  - task: credhub-interpolate
    image: platform-automation-image
    file: platform-automation-tasks/tasks/credhub-interpolate.yml
    input_mapping:
      files: config
    params:
      # all required
      CREDHUB_CA_CERT: ((credhub_ca_cert))
      CREDHUB_CLIENT: ((credhub_client))
      CREDHUB_SECRET: ((credhub_secret))
      CREDHUB_SERVER: ((credhub_server))
      PREFIX: /private-foundation
      INTERPOLATION_PATHS: foundation/config-path
      SKIP_MISSING: true
```

- the [`upload-product`][upload-product] option `--sha256` has been changed to `--shasum`.
  IF you are using the `--config` flag in `upload-product`, your config file will need to update from:
```yaml
# OLD upload-product-config.yml PRIOR TO 3.0.0 RELEASE
product-version: 1.2.3-build.4
sha256: 6daededd8fb4c341d0cd437a
```
  to:
```yaml hl_lines="3"
# NEW upload-product-config.yml FOR 3.0.0 RELEASE
product-version: 1.2.3-build.4
shasum: 6daededd8fb4c341d0cd437a # NOTE the name of this value is changed
```
  This change was added to future-proof the param name for when sha256 is no longer the
  de facto way of defining shasums.

### What's New
- The new command [`assign-multi-stemcell`][assign-multi-stemcell] assigns multiple stemcells to a provided product.
  This feature is only available in OpsMan 2.6+.
- [`download-product`][download-product] ensures sha sum checking when downloading the file from Tanzu Network.
- [`download-product`][download-product] can now disable ssl validation when connecting to Tanzu Network.
  This helps with environments with SSL and proxying issues.
  Add `pivnet-disable-ssl: true` in your [download-product-config][download-product-config] to use this feature.
- On [GCP][inputs-outputs-gcp], if you did not assign a public IP, Google would assign
  one for you. This has been changed to only assign a public IP if defined in your `opsman.yml`.
- On [Azure][inputs-outputs-azure], if you did not assign a public IP, Azure would assign
  one for you. This has been changed to only assign a public IP if defined in your `opsman.yml`.
- `om interpolate` (example in the [test task][test-interpolate]) now supports
   the ability to accept partial vars files. This is added support for users who may also be using
   credhub-interpolate or who want to mix interpolation methods. To make use of this feature, include
   the `--skip-missing` flag.
- [`credhub-interpolate`][credhub-interpolate] now supports the `SKIP_MISSING`
   parameter. For more information on how to use this feature and if it fits for your foundation(s), see the
   [Secrets Handling][secrets-handling-multiple-sources] section.
- the [reference pipeline][reference-pipeline] has been updated to give an example of
  [`credhub-interpolate`][credhub-interpolate] in practice. For more information
  about credhub, see [Secrets Handling][secrets-handling-multiple-sources]
- `om` now has support for `config-template` (a Platform Automation Toolkit encouraged replacement of
   `tile-config-generator`). This is a experimental command that can only be run currently using `docker run`.
   For more information and instruction on how to use `config-template`, please see
   [Creating a Product Config File][product-configuration-from-pivnet].
- [`upload-stemcell`][upload-stemcell] now supports the ability to include a config file.
  This allows you to define an expected `shasum` that will validate the calculated shasum of the provided
  `stemcell` uploaded in the task. This was added to give feature parity with [`upload-product`][upload-product]
- [Azure][inputs-outputs-azure] now allows NSG(network security group) to be optional.
  This change was made because NSGs can be assigned at the subnet level rather than just the VM level. This
  param is also not required by the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/vm?view=azure-cli-latest).
  Platform Automation Toolkit now reflects this.
- [staged-director-config][staged-director-config] now supports returning multiple IaaS
  configurations. `iaas-configurations` is a top level key returned in Ops Manager 2.2+. If using an Ops
  Manager 2.1 or earlier, `iaas_configuration` will continue to be a key nested under `properties-configuration`.
- [configure-director][configure-director] now supports setting multiple IaaS configurations.
  If using this feature, be sure to use the top-level `iaas-configurations` key, rather than the nested
  `properties-configuration.iaas_configuration` key. If using a single IaaS, `properties-configuration.iaas_configuration`
  is still supported, but the new `iaas_configurations` top-level key is recommended.

    ```yaml hl_lines="2"
    # Configuration for 2.2+
    iaas-configurations:
    - additional_cloud_properties: {}
      name: ((iaas-configurations_0_name))
    - additional_cloud_properties: {}
      name: ((iaas-configurations_1_name))
      ...
    networks-configuration: ...
    properties-configuration: ...
    ```

    ```yaml hl_lines="5"
    # Configuration 2.1 and earlier
    networks-configuration: ...
    properties-configuration:
        director_configuration: ...
        iaas_configuration:
          additional_cloud_properties: {}
          name: ((iaas-configurations_0_name))
          ...
        security_configuration: ...
    ```

### Bug Fixes
- OpenStack would sometimes be unable to associate the public IP when creating the VM, because it was
  waiting for the VM to come up. The `--wait` flag has been added to validate that the VM creation is
  complete before more work is done to the VM.
- [`credhub-interpolate`][credhub-interpolate] now accepts multiple files for the `INTERPOLATION_PATHS`.
- CVE update to container image. Resolves [USN-3911-1](https://usn.ubuntu.com/3911-1/).
  (related to vulnerabilities with `libmagic1`. While none of our code directly used these,
  they are present on the image.)
- Improved error messaging for [vSphere][inputs-outputs-vsphere] VM creation if neither `ssh-password` or `ssh-public-key` are set.
  One or the other is required to create a VM.

{% include ".internal_link_url.md" %}
{% include ".external_link_url.md" %}
