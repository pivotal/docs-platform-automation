

<<<<<<< HEAD
The following describes the procedure for downloading, installing, and confirming your install of Platform Automation.
=======
The following describes the procedure for downloading, installing and testing the setup of Platform Automation for PCF.
>>>>>>> 3e391eb... update introduction and report an issue

### Prerequisites

You'll need the following in order to setup Platform Automation for PCF.

* Deployed [Concourse][concourse]

    Platform Automation for PCF is based on Concourse CI.
    We recommend that you have some familiarity with Concourse before getting started.
    If you are new to Concourse, [Concourse CI Tutorials](https://docs.pivotal.io/p-concourse/guides.html) would be a good place to start.
    
* Persisted datastore that can be accessed by Concourse resource (e.g. s3, gcs, minio)
<<<<<<< HEAD
* Pivnet access to [Platform Automation][pivnet-platform-automation]
* Basic knowledge of [YAML][yaml]

    The Concourse pipelines, tasks, and configuration files all use YAML. There are
    a number of tutorials online to teach the basics of this format. Additionally, 
    extensions exist for all major text editors that provide yaml linting, 
    validation, and editing support.

_If you would like to get started with Platform Automation with a guided How To Guide,
see [How To Guide: Upgrading an Existing OpsMan][how-to-upgrade-opsman]. Otherwise,
for a quick start, see the instructions below._
=======
* Pivnet access to [Platform Automation for PCF][pivnet-platform-automation]
>>>>>>> 3e391eb... update introduction and report an issue

### Download

1. Download the latest [Platform Automation for PCF][pivnet-platform-automation] from Pivnet.
   This includes:
    * `Concourse Tasks`
    * `Docker Image for Concourse Tasks`

2. Store the `platform-automation-image-*.tgz`
   in a blobstore that can be accessed via a Concourse pipeline.

3. Store the `platform-automation-tasks-*.zip`
   in a blobstore that can be accessed via a Concourse pipeline.

### Testing Setup

Next we'll create a test pipeline to see if the assets can be accessed correctly.
   This pipeline runs a test task, which ensures that all the parts work correctly.

!!! Info
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
