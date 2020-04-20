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
