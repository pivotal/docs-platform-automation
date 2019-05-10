---
title: Release Notes
owner: PCF Platform Automation
---

These are release notes for Platform Automation for PCF.

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