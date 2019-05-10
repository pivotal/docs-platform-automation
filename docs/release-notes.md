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


## v2.2.0-beta.1
**Release Date** Friday, April 26, 2019

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


{% include ".internal_link_url.md" %}
