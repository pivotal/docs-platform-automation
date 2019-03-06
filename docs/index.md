---
title: Platform Automation for PCF
owner: PCF Platform Automation
---

!!! info
    Platform Automation for Pivotal Cloud Foundry (PCF)
    is currently in beta. For questions and/or to report an issue please contact your primary Pivotal contact. See release notes for latest information regarding new features and any breaking changes.

 Platform Automation for PCF provides the building blocks to create a repeatable and reusable automated pipeline(s) for upgrading and installing PCF foundations.

In this introduction we'll cover:

* About Platform Automation
* Platform Automation and Ops Manager
* How to download and test the setup of Platform Automation  

## About Platform Automation for PCF

* Platform Automation for PCF uses [om][om],
(and by extension, the Ops Manager API)
to enable command-line interaction with Ops Manager
([Understanding the Ops Manager Interface][pivotalcf-understanding-opsman])
* Platform Automation for PCF includes a documented reference pipeline
showing one possible configuration to use tasks
* Platform Automation for PCF comes bundled with Concourse [tasks][concourse-task-definition]
that demonstrate how to use these tasks
in a containerized Continuous Integration (CI) system. Platform Automation for PCF tasks are:

    * Legible: They use
human-readable YAML files which can be edited and managed

    * Modular: Each task has defined inputs and outputs
that perform granular actions

    * Built for Automation: Tasks are idempotent,
so re-running them in a CI won't break builds

    * Not Comprehensive: Workflows that use Platform Automation for PCF
may also contain `om` commands, custom tasks,
and even interactions with the Ops Manager user interface.
Platform Automation for PCF is a set of tools to use alongside other tools,
rather than a comprehensive solution.

The [Task Reference][task-reference] topic discusses these example tasks further.


!!! info
    If your current pipeline is based on PCF Pipelines,
    we recommend building a replacement pipeline with the new tooling,
    as opposed to trying to modify your existing pipeline to use the new tools.
    Since Platform Automation for PCF can easily take over management of an existing Ops Manager,
    this should be fairly straightforward.

## Ops Manager and Platform Automation for PCF

The following table compares how Ops Manager
and Platform Automation for PCF might run a typical sequence of PCF operations:

<table border="1">
  <tr>
    <th></th>
    <th>Ops Manager</th>
    <th>Platform Automation for PCF</th>
  </tr><tr>
    <th>When to Use</th>
    <th>First install and minor upgrades</th>
    <th>Config changes and patch upgrades</th>
  </tr><tr>
    <th>1. Create Ops Manager VM</th>
    <td>Manually prepare IaaS and create Ops Manager VM</td>
    <td><code>create-vm</code></td>
  </tr><tr>
    <th>2. Configure Who Can Run Ops</th>
    <td>Manually configure internal UAA or external identity provider</td>
    <td><code>configure-authentication</code> or <code>configure-saml-authentication</code></td>
  </tr><tr>
    <th>3. Configure BOSH</th>
    <td>Manually configure BOSH Director</td>
    <td><code>configure-director</code> with settings saved from BOSH Director with same version</td>
  </tr><tr>
    <th>4. Add Products</th>
    <td>Click <strong>Import a Product</strong> to upload file, then <strong>+</strong> to add tile to Installation Dashboard</td>
    <td><code>upload-and-stage-product</code></td>
  </tr><tr>
    <th>5. Configure Products</th>
    <td>Manually configure product tiles</td>
    <td><code>configure-product</code> with settings saved from tiles with same version</td>
  </tr><tr>
    <th>6. Deploy Products</th>
    <td>Click <strong>Apply Changes</strong></td>
    <td><code>apply-changes</code></td>
  </tr><tr>
    <th>7. Upgrade</th>
    <td>Manually export existing Ops Manager settings, power off the VM, then create a new, updated
    Ops Manager VM</td>
    <td><code>export-installation</code> then <code>upgrade-opsman</code></td>
  </tr>
</table>


## Downloading and Testing Platform Automation

The following describes the procedure for downloading, installing and testing the setup of Platform Automation.

### Prerequisites

You'll need the following in order to setup Platform Automation.

* Deployed Concourse

!!! info
    Platform Automation for PCF is based on Concourse CI.
    We recommend that you have some familiarity with Concourse before getting started.
    If you are new to Concourse, [Concourse CI Tutorials](https://docs.pivotal.io/p-concourse/guides.html) would be a good place to start.

* Persisted datastore that can be accessed by Concourse resource (e.g. s3, gcs, minio)
* Pivnet access to [Platform Automation][pivnet-platform-automation]

### Download Platform Automation

1. Download the latest [Platform Automation][pivnet-platform-automation] from Pivnet.
   This includes:
    * `Concourse Tasks`
    * `Docker Image for Concourse Tasks`

2. Store the `platform-automation-image-*.tgz`
   in a blobstore that can be accessed via a Concourse pipeline.

3. Store the `platform-automation-tasks-*.zip`
   in a blobstore that can be accessed via a Concourse pipeline.

### Testing Platform Automation Setup

Next we'll create a test pipeline to see if the assets can be accessed correctly.
   This pipeline runs a test task, which ensures that all the parts work correctly.

!!! info
       The pipeline can use any blobstore.
       We choose S3 because the resource natively supported by Concourse.
       The S3 Concourse resource also supports S3-compatible blobstores (e.g. minio).
       See [S3 Resource](https://github.com/concourse/s3-resource#source-configuration) for more information.
       If you want to use other blobstore, you need to provide a custom [resource type](https://concourse-ci.org/resource-types.html).

 In order to test the setup, fill in the S3 resource credentials and set the below pipeline on your Concourse instance.

```yaml
resources:
- name: platform-automation-tasks-s3
  type: s3
  source:
    access_key_id: ((access_key_id))
    secret_access_key: ((secret_access_key))
    region_name: ((region))
    bucket: ((bucket))
    regexp: platform-automation-tasks-(.*).zip

- name: platform-automation-image-s3
  type: s3
  source:
    access_key_id: ((access_key_id))
    secret_access_key: ((secret_access_key))
    region_name: ((region))
    bucket: ((bucket))
    regexp: platform-automation-image-(.*).tgz

jobs:
- name: test-resources
  plan:
  - aggregate:
    - get: platform-automation-tasks-s3
      params:
        unpack: true
    - get: platform-automation-image-s3
      params:
        unpack: true
  - task: test-resources
    image: platform-automation-image-s3
    file: platform-automation-tasks-s3/tasks/test.yml
```


{% include ".internal_link_url.md" %}
{% include ".external_link_url.md" %}
