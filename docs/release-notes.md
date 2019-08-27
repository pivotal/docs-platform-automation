---
title: Release Notes
owner: PCF Platform Automation
---

{% include "./.opsman_filename_change_note.md" %}

!!! warning "Azure Updating to 2.5"
     Ops Manager will be removing the necessity to provide availability zones for azure.
     If your `director.yml`(see [`staged-director-config`](./tasks.md#staged-director-config))
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
     [`staged-director-config`](./tasks.md#staged-director-config) to update your `director.yml`.

## v4.1.0
** Release Date** Someday sometime

### What's New
- [Ops Manager config for vSphere][inputs-outputs-vsphere] now validates the required properties
- The new task [expiring-certificates]
  fails if there are any expiring certificates
  in a user specified time range.

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
  To opt in, you must get the Telemetry tool from [Pivnet][telemetry],
  create a [config file][telemetry-config], 
  and add the [collect-telemetry][collect-telemetry] and [send-telemetry][send-telemetry] tasks to your pipeline. 
  For an example, please see the [Reference Pipelines][reference-pipeline]. 

## v4.0.1

**Release Date** Coming Soon

### Bug Fixes
- CVE update to container image. Resolves [USN-4108-1](https://usn.ubuntu.com/4108-1/)
  (related to vulnerabilities with `libzstd`. While none of our code directly used these,
  they are present on the image.)
- Bumped the following low-severity CVE packages: `linux-libc-dev`

## v4.0.0

**Release Date** August 28, 2019

### Breaking Changes

- The tasks have been updated to extract their `bash` scripting into a separate script.
  The tasks' script can be used different CI/CD systems like Jenkins.

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
  can create a UAA client on the Ops Manager vm.
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

## v3.0.8
**Release Date** Coming Soon

### Bug Fixes
- CVE update to container image. Resolves [USN-4108-1](https://usn.ubuntu.com/4108-1/)
  (related to vulnerabilities with `libzstd`. While none of our code directly used these,
  they are present on the image.)
- Bumped the following low-severity CVE packages: 
  `libpython2.7`, `libpython2.7-dev`, `libpython2.7-minimal`, `libpython2.7-stdlib`, `libssl1.1`
  `openssl`, `python-cryptography`, `python2.7`, `python2.7-dev`, `python2.7-minimal`

## v3.0.7
**Release Date** August 28, 2019

### Bug Fixes
- When using AWS to create the Ops Manager VM with encrypted disks,
  the task [`create-vm`][create-vm] and [`upgrade-opsman`][upgrade-opsman] will wait for disk encryption to be completed.
  An exponential backoff will be and timeout after an hour if disk is not ready.
- CVE update to container image. Resolves [USN-4071-1](https://usn.ubuntu.com/4071-1/)
  (related to vulnerabilities with `patch`. While none of our code directly used these,
  they are present on the image.)
- Bumped the following low-severity CVE packages: 
  `linux-libc-dev`, `libldap-2.4-2`, `libldap-common`, `linux-libc-dev`

## v3.0.5
**Release Date** July 22, 2019

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
**Release Date** Thursday, July 11, 2019

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

- CVE update to container image. Resolves [USN-4040-1](https://usn.ubuntu.com/4040-1/)
  (related to vulnerabilities with `Expat`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-4038-1](https://usn.ubuntu.com/4038-1/) and [USN-4038-3](https://usn.ubuntu.com/4038-3/)
  (related to vulnerabilities with `bzip`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-4019-1](https://usn.ubuntu.com/4019-1/)
  (related to vulnerabilities with `SQLite`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [CVE-2019-11477](https://people.canonical.com/~ubuntu-security/cve/2019/CVE-2019-11477.html)
  (related to vulnerabilities with `linux-libc-dev`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-4049-1](https://usn.ubuntu.com/4049-1/)
  (related to vulnerabilities with `libglib`. While none of our code directly used these,
  they are present on the image.)

## v3.0.2
**Release Date** Monday, July 8th, 2019

### Bug Fixes
- CVE update to container image. Resolves [USN-4014-1](https://usn.ubuntu.com/4014-1/)
  (related to vulnerabilities with `GLib`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-4015-1](https://usn.ubuntu.com/4015-1/)
  (related to vulnerabilities with `DBus`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-3999-1](https://usn.ubuntu.com/3999-1/)
  (related to vulnerabilities with `GnuTLS`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-4001-1](https://usn.ubuntu.com/4001-1/)
  (related to vulnerabilities with `libseccomp`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-4004-1](https://usn.ubuntu.com/4004-1/)
  (related to vulnerabilities with `Berkeley DB`. While none of our code directly used these,
  they are present on the image.)
- CVE update to container image. Resolves [USN-3993-1](https://usn.ubuntu.com/3993-1/)
  (related to vulnerabilities with `curl`. While none of our code directly used these,
  they are present on the image.)

## v3.0.1
**Release Date** Friday, May 24th, 2019

### Breaking Changes
- `om` will now follow conventional Semantic Versioning,
  with breaking changes in major bumps,
  non-breaking changes for minor bumps,
  and bug fixes for patches.
- The [`credhub-interpolate`](./tasks.md#credhub-interpolate) task can have multiple
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

- the [`upload-product`](./tasks.md#upload-product) option `--sha256` has been changed to `--shasum`.
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
- The new command [`assign-multi-stemcell`](./tasks.md#assign-multi-stemcell) assigns multiple stemcells to a provided product.
  This feature is only available in OpsMan 2.6+.
- [`download-product`](./tasks.md#download-product) ensures sha sum checking when downloading the file from Pivotal Network.
- [`download-product`](./tasks.md#download-product) can now disable ssl validation when connecting to Pivotal Network.
  This helps with environments with SSL and proxying issues.
  Add `pivnet-disable-ssl: true` in your [download-product-config] to use this feature.
- On [GCP](./inputs-outputs.md#gcp), if you did not assign a public IP, Google would assign
  one for you. This has been changed to only assign a public IP if defined in your `opsman.yml`.
- On [Azure](./inputs-outputs.md#azure), if you did not assign a public IP, Azure would assign
  one for you. This has been changed to only assign a public IP if defined in your `opsman.yml`.
- `om interpolate` (example in the [test task](./tasks.md#test-interpolate)) now supports
   the ability to accept partial vars files. This is added support for users who may also be using
   credhub-interpolate or who want to mix interpolation methods. To make use of this feature, include
   the `--skip-missing` flag.
- [`credhub-interpolate`](./tasks.md#credhub-interpolate) now supports the `SKIP_MISSING`
   parameter. For more information on how to use this feature and if it fits for your foundation(s), see the
   [Secrets Handling](./concepts/secrets-handling.md#multiple-sources) section.
- the [reference pipeline](./pipelines/multiple-products.md) has been updated to give an example of
  [`credhub-interpolate`](./tasks.md#credhub-interpolate) in practice. For more information
  about credhub, see [Secrets Handling](./concepts/secrets-handling.md#multiple-sources)
- `om` now has support for `config-template` (a Platform Automation encouraged replacement of
   `tile-config-generator`). This is a experimental command that can only be run currently using `docker run`.
   For more information and instruction on how to use `config-template`, please see
   [Creating a Product Config File](./how-to-guides/creating-a-product-config-file.md#from-pivnet).
- [`upload-stemcell`](./tasks.md#upload-stemcell) now supports the ability to include a config file.
  This allows you to define an expected `shasum` that will validate the calculated shasum of the provided
  `stemcell` uploaded in the task. This was added to give feature parity with [`upload-product`](./tasks.md#upload-product)
- [Azure](./inputs-outputs.md#azure) now allows NSG(network security group) to be optional.
  This change was made because NSGs can be assigned at the subnet level rather than just the VM level. This
  param is also not required by the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/vm?view=azure-cli-latest).
  Platform Automation now reflects this.
- [staged-director-config](./tasks.md#staged-director-config) now supports returning multiple IaaS
  configurations. `iaas-configurations` is a top level key returned in Ops Manager 2.2+. If using an Ops
  Manager 2.1 or earlier, `iaas_configuration` will continue to be a key nested under `properties-configuration`.
- [configure-director](./tasks.md#configure-director) now supports setting multiple IaaS configurations.
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
- CVE update to container image. Resolves [USN-3911-1](https://usn.ubuntu.com/3911-1/)
  (related to vulnerabilities with `libmagic1`. While none of our code directly used these,
  they are present on the image.)
- Improved error messaging for [vSphere](./inputs-outputs.md#gcp) VM creation if neither `ssh-password` or `ssh-public-key` are set.
  One or the other is required to create a VM.

{% include ".internal_link_url.md" %}
{% include ".external_link_url.md" %}
