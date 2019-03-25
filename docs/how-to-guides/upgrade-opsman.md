# How to: Upgrade an Existing Ops Manager

The following is a How To Guide on setting up and using Platform Automation if you
already have a foundation that needs to be automated, or if you are coming from a 
different form of automation (such as `pcf-pipelines`)

## Prerequisites

In addition to the prerequisites listed in [Downloading and Testing][downloading-and-testing],
the Platform Automation team recommends the following:

* Installed [Docker CLI][docker-cli]
    
    There are a couple one-off tasks that can be either saved in your pipeline, 
    or run once from the command line using our Docker image. The preference to 
    do either is your choice, but the How To Guide will be using the Docker CLI.
    
* Basic knowledge of [Git][git] and [GitHub][github]

    Git is a common distributed version control system for software development projects
    and operators. Several tasks mutate state and configuration files that are best 
    handled automatically in some sort of hosted version control system. For the purposes of the 
    How To Guide, this system will be GitHub.
    
* [Amazon S3][amazon-s3] or [Minio][minio]
    
    While any blobstore can be used, this How To Guide will be using an s3-compatible blobstore.
    
* A fully installed foundation (either PAS or PKS) with all relevant tiles similarly
  configured and installed
  
    !!! warning
        Upgrading Ops Manager _requires_ that your foundation have no pending apply-changes.
        The exported installation will not reflect any pending changes, and will not export 
        at all if the foundation has not fully installed at least the Ops Manager BOSH director.
        

## Goals and Overview

The goal of this How To Guide is to build up a portion of the [Reference Pipeline][reference-pipeline]
and the [Reference Resources Pipeline][reference-resources]
that is relevant for upgrading Ops Manager for an already existing foundation. This guide will go 
through the following steps:

* Retrieving Ops Manager, PAS, Healthwatch, and Platform Automation from Pivnet and storing 
  in an s3 blobstore
* How to setup a sample github repo with a recommended file structure
* Retrieve the existing config from PAS, Ops Manager, and Healthwatch using `docker run`
* Persisting the configuration external configuration in github
* Separating foundation-specific and secret credentials from the existing foundation, and
  when to store in credhub or in a vars file
* How to interpolate the configs using credhub, and feeding these interpolated configs into 
  the concourse tasks
  
TODO: link the above to the headers below

## Retrieving Resources from Pivnet

When creating a Concourse pipeline, we will expand the following base structure:
```yaml
resource_types:
resources:
jobs:
```

Concourse has many [Resource Types][concourse-resource-types] built in, but for the 
purpose of this reference pipeline, we will be utilizing the [Pivotal pivnet-resource][pivnet-resource]
to directly communicate with and download products from Pivnet.

To tell concourse that we will be using the Pivnet resource, we will have to include
the following:
```yaml
resource_types:
- name: pivnet
  type: docker-image
  source:
    repository: pivotalcf/pivnet-resource
    tag: latest-final
```

After listing the "custom" resource type, we can then list the resources that our foundation
requires. For this guide, our foundation includes: Ops Manager, Pivotal Application Service (PAS),
and Healthwatch. The general automated workflow for fetching and storing resources is as follows:

TODO: link to the appropriate sections

1. Setup your s3 with the appropriate credentials/buckets for your foundation
1. [Download product and stemcell](#download-product-and-products-stemcell) (using `download-product`) 
   and store in an s3 bucket
1. Download Platform Automation from Pivnet

The resources required to accomplish these tasks include:

* healthwatch-product s3 storage location
* healthwatch-stemcell s3 storage location
* ops-manager s3 storage location
* pas-product s3 storage location
* pas-stemcell s3 storage location
* platform-automation-docker-image s3 storage location
* platform-automation-tasks storage location

To reference the storage locations in Concourse, you are required to have the 

* access_key_id and secret_access_key for accessing the appropriate bucket
* the name of the bucket for storing the product(s)
* the region the bucket is located in
* a regex that describes the filename of the product being stored (to prevent the
  wrong product/version from being stored/accessed later) 

The following example assumes that all of your products live in the same s3 bucket, thus
their `regexp` are very specific to match the slug/version.

TODO: tabs for each of the resources as shown in "reference/pipeline" configs
```yaml
resources:
- name: healthwatch-product
  type: s3
  source:
    access_key_id: ((s3.access_key_id))
    bucket: ((s3.buckets.pivnet_products))
    region_name: ((s3.region_name))
    secret_access_key: ((s3.secret_access_key))
    regexp: \[p-healthwatch,(.*)\]p-healthwatch-.*.pivotal

- name: healthwatch-stemcell
  type: s3
  source:
    access_key_id: ((s3.access_key_id))
    bucket: ((s3.buckets.pivnet_products))
    region_name: ((s3.region_name))
    secret_access_key: ((s3.secret_access_key))
    regexp: healthwatch-stemcell/\[stemcells-ubuntu-xenial,(.*)\]bosh-stemcell-.*-vsphere.*\.tgz

- name: opsman-product
  type: s3
  source:
    access_key_id: ((s3.access_key_id))
    bucket: ((s3.buckets.pivnet_products))
    region_name: ((s3.region_name))
    secret_access_key: ((s3.secret_access_key))
    regexp: \[ops-manager,(.*)\].*.ova

- name: pas-product
  type: s3
  source:
    access_key_id: ((s3.access_key_id))
    bucket: ((s3.buckets.pivnet_products))
    region_name: ((s3.region_name))
    secret_access_key: ((s3.secret_access_key))
    regexp: \[elastic-runtime,(.*)\]cf-.*.pivotal

- name: pas-stemcell
  type: s3
  source:
    access_key_id: ((s3.access_key_id))
    bucket: ((s3.buckets.pivnet_products))
    region_name: ((s3.region_name))
    secret_access_key: ((s3.secret_access_key))
    regexp: pas-stemcell/\[stemcells-ubuntu-xenial,(.*)\]bosh-stemcell-.*-vsphere.*\.tgz
    
- name: platform-automation-tasks
  type: s3
  source:
    access_key_id: ((s3.access_key_id))
    bucket: ((s3.buckets.pivnet_products))
    region_name: ((s3.region_name))
    secret_access_key: ((s3.secret_access_key))
    regexp: platform-automation-tasks-(.*).zip

- name: platform-automation-image
  type: s3
  source:
    access_key_id: ((s3.access_key_id))
    bucket: ((s3.buckets.pivnet_products))
    region_name: ((s3.region_name))
    secret_access_key: ((s3.secret_access_key))
    regexp: platform-automation-image-(.*).tgz
```

To retrieve the platform-automation product, there is no stemcell, and thus the download
process is much simpler than with Ops Manager products. Therefore, we can use the Pivnet
resource we defined earlier and pull from Pivnet directly. The product can be stored in s3
the same way that the other products can. We can add these resources to our pipeline:
```yaml
- name: platform-automation-pivnet
  type: pivnet
  source:
    api_token: ((pivnet_token))
    product_slug: platform-automation
    product_version: 2\.(.*)
    sort_by: semver

- name: platform-automation-tasks
  type: s3
  source:
    access_key_id: ((s3.access_key_id))
    bucket: ((s3.buckets.pivnet_products))
    region_name: ((s3.region_name))
    secret_access_key: ((s3.secret_access_key))
    regexp: platform-automation-tasks-(.*).zip

- name: platform-automation-image
  type: s3
  source:
    access_key_id: ((s3.access_key_id))
    bucket: ((s3.buckets.pivnet_products))
    region_name: ((s3.region_name))
    secret_access_key: ((s3.secret_access_key))
    regexp: platform-automation-image-(.*).tgz
```

### Parametrizing Secrets, and Using Credhub Interpolate 

This example pipeline will make heavy use of the [`credhub-interpolate`][credhub-interpolate]
task. For more information on how this works, and how to set it up and use it properly, 
please see the [Secrets Handling][secrets-handling] page. 

The [config file][download-product-config] used in the following section mixes secret and 
non-secret variables. When choosing which variables to keep in the config file, and which ones
to `((parametrize))`, you should consider whether public access to the variable would be a 
concern. If choosing to parametrize, you will need to first use 
[`credhub-interpolate`][credhub-interpolate] to substitute the Credhub values into the config 
for the next task to use. 

!!! info 
    Parametrized configurations that are interpolated by Credhub return a config file with the 
    formerly parametrized variables with their Credhub values. Concourse VMs are ephemeral, and
    these full config files are only available in the specific job, and will not be persisted.

An example of how to use this in the resources pipeline is shown below. We will be defining this
"task" external to jobs and resources, so that it can be used in multiple jobs while keeping the yaml
clean.
```yaml
resource-types: ...
resources: ...

credhub-interpolate: &credhub-interpolate
  image: platform-automation-image
  file: platform-automation-tasks/tasks/credhub-interpolate.yml
  params:
    CREDHUB_CLIENT: ((credhub-client))
    CREDHUB_SECRET: ((credhub-secret))
    CREDHUB_SERVER: ((credhub-server))
    PREFIX: '/pipeline/vsphere'
    INTERPOLATION_PATH: "download-product-configs"
  input_mapping:
    files: config
  output_mapping:
    interpolated-files: config
      
jobs: ...
```

When referencing the above "task" we will be calling it with the yaml below. This will expand the 
anchor `*credhub-interpolate` with the concourse-readable data we defined in `&credhub-interpolate` above.
```yaml
- task: credhub-interpolate
  <<: *credhub-interpolate
```


### Download Product and Product's Stemcell 

Before downloading a product, you first need a [config file][download-product-config]
for [download-product][download-product] to read. In the sample config below, the fields
that are uncommented will be used in this how-to guide. s3-specific fields are only required 
if using the `download-product-s3` command. If you are using Pivnet directly in your 
pipeline, this resources pipeline is not necessary, and neither are the s3-specific fields.
For this guide, these fields are required, and will be necessary later.

Commented out fields are entirely optional and should only be used if you have a need to do 
so. Explanations for each field are given below.

{% code_snippet 'examples', 'download-product-config-parametrized' %}

To fetch a product from Pivnet, concourse needs to know
 
* what image it will run the task on (`platform-automation-image`)
* where the task file will come from (`platform-automation-tasks`) 
* what config file it will read from to get data about pivnet and the tile (this is 
  the `download-product-config` created above)
* how to map the output from the task to something you will use later
* where to put the output resources created in the task

These requirements gathered together and executed in a task could look like the snippet below.
The snippet involves downloading Healthwatch. However, Healthwatch can be easily replaced by
any other tile. The only pieces that would need to change are the task name (if being specific), 
the name of the stemcell (if mapping), the name of the `download-product-config`, and the `put`s 
specified after the product and stemcell are downloaded. 
```yaml
- task: download-healthwatch-product-and-stemcell
  image: platform-automation-image
  file: platform-automation-tasks/tasks/download-product.yml
  params:
    CONFIG_FILE: download-product-configs/healthwatch.yml
  output_mapping: {downloaded-stemcell: healthwatch-stemcell}
  - aggregate:
  - put: healthwatch-product
    params:
      file: downloaded-product/*.pivotal
  - put: healthwatch-stemcell
    params:
      file: healthwatch-stemcell/*.tgz
```

However, Concourse requires you to aggregate any number of tasks into a job. For convenience,
and ease of explanation, we have created a separate job for each product. These tasks can easily be
combined into a single job. Benefits of doing could include only running `credhub-interpolate` once 
(instead of for each job). A downside of structuring your job with all of the tasks include the 
inability to rerun a particular section of the job that failed, so Concourse would run each task
again when the job was triggered a second time.

To make sure your blobstore always has the most recent version of a pivnet product, you can use the
built-in time resource, to tell the `fetch` jobs how often to run and attempt to download a new version
of the product and/or stemcell. To add this functionality to your pipeline, you must include the time
resource in your `resources:` section:
```yaml
resources:
- name: daily
  type: time
  source:
    interval: 24h
```

If included, this resource can be referenced in any appropriate job, and you can set the job to trigger
on that daily (or custom) interval.

An example of a `fetch-healthwatch` job is as shown below. The job includes the task we created above,
the daily time trigger, and the interpolate created in an [earlier step](#parametrizing-secrets-and-using-credhub-interpolate).
```yaml
jobs:
- name: fetch-healthwatch
  plan:
  - aggregate:
    - get: daily
      trigger: true
    - get: platform-automation-image
      params:
        unpack: true
    - get: platform-automation-tasks
      params:
        unpack: true
    - get: config
  - task: credhub-interpolate
    <<: *credhub-interpolate
  - task: download-healthwatch-product-and-stemcell
    image: platform-automation-image
    file: platform-automation-tasks/tasks/download-product.yml
    params:
      CONFIG_FILE: download-product-configs/healthwatch.yml
    output_mapping: {downloaded-stemcell: healthwatch-stemcell}
  - aggregate:
    - put: healthwatch-product
      params:
        file: downloaded-product/*.pivotal
    - put: healthwatch-stemcell
      params:
        file: healthwatch-stemcell/*.tgz
```

TODO: tab to show example of each product "job" defined (like in reference/pipeline.html configs)
This step can then be repeated for all products desired:
```yaml
jobs:
- name: fetch-healthwatch
  plan:
  - aggregate:
    - get: daily
      trigger: true
    - get: platform-automation-image
      params:
        unpack: true
    - get: platform-automation-tasks
      params:
        unpack: true
    - get: config
  - task: credhub-interpolate
    <<: *credhub-interpolate
  - task: download-healthwatch-product-and-stemcell
    image: platform-automation-image
    file: platform-automation-tasks/tasks/download-product.yml
    params:
      CONFIG_FILE: download-product-configs/healthwatch.yml
    output_mapping: {downloaded-stemcell: healthwatch-stemcell}
  - aggregate:
    - put: healthwatch-product
      params:
        file: downloaded-product/*.pivotal
    - put: healthwatch-stemcell
      params:
        file: healthwatch-stemcell/*.tgz

- name: fetch-opsman
  plan:
  - aggregate:
    - get: daily
      trigger: true
    - get: platform-automation-image
      params:
        unpack: true
    - get: platform-automation-tasks
      params:
        unpack: true
    - get: config
  - task: credhub-interpolate
    <<: *credhub-interpolate
  - task: download-opsman-image
    image: platform-automation-image
    file: platform-automation-tasks/tasks/download-product.yml
    params:
      CONFIG_FILE: download-product-configs/opsman.yml
  - aggregate:
    - put: opsman-product
      params:
        file: downloaded-product/*

- name: fetch-pas
  plan:
  - aggregate:
    - get: daily
      trigger: true
    - get: platform-automation-image
      params:
        unpack: true
    - get: platform-automation-tasks
      params:
        unpack: true
    - get: config
  - task: credhub-interpolate
    <<: *credhub-interpolate
  - task: download-pas-product-and-stemcell
    image: platform-automation-image
    file: platform-automation-tasks/tasks/download-product.yml
    params:
      CONFIG_FILE: download-product-configs/pas.yml
    output_mapping: {downloaded-stemcell: pas-stemcell}
  - aggregate:
    - put: pas-product
      params:
        file: downloaded-product/*.pivotal
    - put: pas-stemcell
      params:
        file: pas-stemcell/*.tgz
```

### Download Platform Automation from Pivnet

Because downloading Platform Automation does not require the use of `download-product`, the task for 
this is much simpler. The Platform Automation team recommends always triggering the 
`fetch-platform-automation` when there is a new version available for the major version you defined (to
get all required security updates and bug fixes, and be assured there are no breaking changes to your
installation. For more information about how Platform Automation uses strict semver, and why this is safe,
please reference [Compatibility and Versioning][semantic-versioning].

To download the Platform Automation tasks and the Docker image, and put it into your s3 blobstore, add
the following job:
```yaml
- name: fetch-platform-automation
  plan:
  - get: platform-automation-pivnet
    trigger: true
  - aggregate:
    - put: platform-automation-tasks
      params:
        file: platform-automation-pivnet/*tasks*.zip
    - put: platform-automation-image
      params:
        file: platform-automation-pivnet/*image*.tgz
``` 

### A Complete Resources Pipeline

Now that we have built up the resources pipeline, you can find this full example on the 
[Reference Pipeline][reference-resources] page. This also includes an example of fetching a 
Windows tile, but if you understand the concepts above, you can use the Windows tile, the mySQL tile, 
or any other tile you desire for your foundation.



{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
 