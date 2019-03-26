# How to: Upgrade an Existing Ops Manager

The following is a _How To Guide_ on setting up and using Platform Automation.
This guide assumes you already have a foundation that needs to be automated, 
or you are coming from a different form of automation (such as `pcf-pipelines`)

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
    
    While any blobstore may be used, this _How To Guide_ will be 
    using an s3-compatible blobstore.
    
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
* How to setup a sample github repo 
* Setup recommended file structure
* Create required files for Upgrade
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

## Sample Github repository and file structure

In this section we will dive into the distributed version control aspects of 
how state is managed by Platform Automation. We will set up a sample Github repository 
and go over the recommended folder structure for the repository. 

### Git and Github

Because different tasks update the state and configuration files automatically, 
some form of version control is required. Git is a commonly used version control tool
that tracks local history and code changes various users make to files inside a predefined folder
called a repository (or more often, a repo). To learn more about git, [read this short git handbook][github-git-handbook].

Git is great for working on a local, self hosted repository, but often, it's necessary to
access repositories from the web or across multiple computers. Github is a distributed
version control system that provides git functionality across the web. Using a distributed
system will enable the pipeline we are creating to access and update the state and configuration files
automatically through Github without manual intervention from the us.
In this example, we will be using [Github][github], another common version control tool.
For further reading, [this portion of the handbook][github-git-handbook-github] explains how Github
fits into the overall version control workflow. 

To create our Github repo:

1. You must have a github account. 
Login or create an account
1. Create a new repository
1. Using the example from the "Example: Start a new repository and publish it to GitHub"
section of the [Git handbook][github-git-handbook] (about 3/4 down the page), 
create a local repo and add your first file

### Creating repo folder structure

You now have both a local git repo and a distributed Github repo. Let's cover the recommended 
folder structure for this repo before we fill it with files:

```bash
├── foundation
│   ├── config
│   ├── env
│   ├── state
│   └── vars
```

Each of the above directories are needed for this How To Guide, and is the recommended starter
structure for configuration management. The pipeline described in this guide will 
[map][concourse-input-mapping] files assuming this file structure.
 
* The `config` directory will hold all of the config files for the products installed on your 
foundation. If using Credhub and/or vars files, these config files should have your 
((parametrized)) values present in them.

* The `env` directory will hold a single `env.yml`, which will be your environment file used by 
each task that interacts with Ops Manager.

* The `vars` directory will hold all of the product-specific vars files needed for your foundation.

* The `state` directory will hold a single `state.yml`, which will need to be created manually if 
upgrading from an existing foundation for the first time, or is created automatically if
installing from a empty foundation. 

### Creating the Required Files

Minimal files required for upgrading an Ops Manager VM include:

* valid state.yml
* valid `opsman.yml` (config)
* valid `env.yml`
* valid Ops Manager image file
* (Optional) vars files -- if supporting multiple foundations
* valid exported Ops Manager installation

**valid state.yml**

If creating a `state.yml` from an existing foundation, use the following as a template, based
on your IaaS:
    
``` yaml tab="AWS"
{% include './examples/state/aws.yml' %}
```

``` yaml tab="Azure"
{% include './examples/state/azure.yml' %}
```

``` yaml tab="GCP"
{% include './examples/state/gcp.yml' %}
```

``` yaml tab="OpenStack"
{% include './examples/state/openstack.yml' %}
```

``` yaml tab="vSphere"
{% include './examples/state/vsphere.yml' %}
```

**valid opsman.yml**

`opsman.yml` is the configuration file required by the `p-automator` tool that exists in the 
Platform Automation Docker image. `p-automator` is an abstraction that calls out to specific 
IaaS CLIs in order to create/update/delete a VM. The optional and required fields detail configurations 
and interfaces for the VM creation and deletion processes supported by the Platform Automation team.

When creating a valid `opsman.yml`, the fields required differ based on your IaaS.
Each field is commented if we believe more info is required:

``` yaml tab="AWS"
{% include './examples/opsman-config/aws.yml' %}
```

``` yaml tab="Azure"
{% include './examples/opsman-config/azure.yml' %}
```

``` yaml tab="GCP"
{% include './examples/opsman-config/gcp.yml' %}
```

``` yaml tab="OpenStack"
{% include './examples/opsman-config/openstack.yml' %}
```

``` yaml tab="vSphere"
{% include './examples/opsman-config/vsphere.yml' %}
```

**valid env.yml**

`env.yml` is a authentication file used by the `om` tool that exists in the Platform Automation
image. This tool interacts directly with the foundation's Ops Manager and thus, the `env.yml` file 
holds authentication information for that Ops Manager. This file is required by `upgrade-opsman` 
because after the vm is recreated, the task will import the existing installation in Ops 
Manager to finish the process.

An example `env.yml` is shown below. If your foundation uses an authentication other than basic
auth, please reference [Inputs and Outputs][env] for more detail on UAA-based authentication. 
As mentioned in the comment, `decryption-passphrase` is required for `import-installation`, and 
is therefore required for `upgrade-opsman`.

{% code_snippet 'examples', 'env' %}

**valid Ops Manager image file**

The image file required for `upgrade-opsman` does not have to be downloaded or created manually.
Instead, it will be included as a resource from an S3 bucket. This resource can also be consumed
directly from Pivnet, but this _How to Guide_ will not be showing that workflow.

**vars files**

If using vars files to store secrets or IaaS agnostic credentials, these files should be included in
your git repo under the `vars` directory. For more information on vars files, see the 
[Secrets Handling][secrets-handling] page. 

**valid exported Ops Manager installation**

`upgrade-opsman` will not allow you to execute the task unless the installation 
provided to the task is a installation provided by Ops Manager itself. In the UI, this is located 
on the [Settings Page][opsman-settings-page] of Ops Manager.

Platform Automation _**highly recommends**_ automatically exporting and persisting the Ops 
Manager installation on a regular basis. In order to do so, you can set your pipeline to run the 
[`export-installation`][export-installation] task on a daily trigger. This should be persisted into 
S3 or a blobstore of your choice.

You can start your pipeline by first creating this `export-installation` task and persisting it in an S3
bucket.

Requirements for this task include:

* the Platform Automation image
* the Platform Automation tasks
* a configuration path for your env file
* interpolation of the env file with credhub
* a resource to store the exported installation into

Starting our concourse pipeline, we need the following resources:
```yaml
resources:
  - name: platform-automation-tasks
    type: s3
    source:
      access_key_id: ((s3.access_key_id))
      secret_access_key: ((s3.secret_access_key))
      region_name: ((s3.region_name))
      bucket: ((s3.buckets.pivnet_products))
      regexp: .*tasks-(.*).zip

  - name: platform-automation-image
    type: s3
    source:
      access_key_id: ((s3.access_key_id))
      secret_access_key: ((s3.secret_access_key))
      region_name: ((s3.region_name))
      bucket: ((s3.buckets.pivnet_products))
      regexp: .*image-(.*).tgz
      
  - name: configuration
    type: git
    source:
      private_key: ((configuration.private_key))
      uri: ((configuration.uri))
      branch: master
      
  - name: installation
    type: s3
    source:
      access_key_id: ((s3.access_key_id))
      secret_access_key: ((s3.secret_access_key))
      region_name: ((s3.region_name))
      bucket: ((s3.buckets.installation))
      regexp: installation-(.*).zip
```

In our `jobs` section, we need a job that will trigger daily to pull down the Ops Manager
installation and store it in S3. This looks like the following:

```yaml
jobs:
  - name: export-installation
    serial: true
    plan:
      - aggregate:
          - get: daily-trigger
            trigger: true
          - get: platform-automation-image
            params:
              unpack: true
          - get: platform-automation-tasks
            params:
              unpack: true
          - get: configuration
          - get: variable
      - task: interpolate-env-creds
        image: platform-automation-image
        file: platform-automation-tasks/tasks/credhub-interpolate.yml
        params:
          CREDHUB_CLIENT: ((credhub-client))
          CREDHUB_SECRET: ((credhub-secret))
          CREDHUB_SERVER: ((credhub-server))
          PREFIX: '/pipeline/vsphere'
          INTERPOLATION_PATH: ((foundation))/config
          SKIP_MISSING: true
        input_mapping:
          files: configuration
        output_mapping:
          interpolated-files: interpolated-configs
      - task: export-installation
        image: platform-automation-image
        file: platform-automation-tasks/tasks/export-installation.yml
        input_mapping:
          env: interpolated-env
        params:
          ENV_FILE: ((foundation))/env/env.yml
          INSTALLATION_FILE: installation-$timestamp.zip
      - put: installation
        params:
          file: installation/installation*.zip
```

Once this resource is persisted, we can safely run `upgrade-opsman`, knowing that we can 
never truly lose our foundation. This is also important in case something happens to the VM
externally (whether accidentally deleted, or a similar disaster occurs). If something _does_
happen to the original Ops Manager VM, this installation can be imported by any newly created Ops Manager
VM.


### Retrieving Existing Ops Manager Director Configuration
If you would like to automate the configuration of your Ops Manager, you first need to externalize
the director configuration. Using Platform Automation, this is done using Docker or by adding a job to
the pipeline.

**Docker**

To get the currently configured Ops Manager configuration, we have to:

1. Import the image
```bash
docker import ${PLATFORM_AUTOMATION_IMAGE_TGZ} platform-automation-image
```
Where `${PLATFORM_AUTOMATION_IMAGE_TGZ}` is the image file downloaded from Pivnet.

2. Then, you can use `docker run` to pass it arbitrary commands.
Here, we're running the `om` CLI to see what commands are available:
```bash
docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
om -h
```

Note:  that this will have access read and write files in your current working directory.
If you need to mount other directories as well, you can add additional `-v` arguments.

The command we will use to extract the current director configuration is called 
[`staged-director-config`][staged-director-config]. This is an `om` command that calls
the Ops Manager API to pull down the currently configured director configuration. To run this
using Docker, you will need the env file created above as ${ENV_FILE}: 

```bash
docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
om --env ${ENV_FILE} staged-director-config --include-placeholders
```

`--include-placeholders` is an optional flag, but highly recommended if you want a full
configuration for your Ops Manager. This flag will replace any fields marked as "secret" 
in your Ops Manager config with ((parametrized)) variables. If you would prefer to not
work with ((parametrized)) variables, you can substitute `--include-placeholders` with
`--include-credentials`.
 
!!! warning
    `--include-credentials` WILL expose passwords and 
    secrets in _plain text_. Therefore, `--include-placeholders` is recommended, but not required.

**Pipeline**

To add [`staged-director-config`] to your pipeline, you will need the following resources:

* the Platform Automation image
* the Platform Automation tasks
* a configuration path for your env file
* a resource to store the exported configuration into

Starting our Concourse pipeline, we need the following resources:
```yaml
resources:
  - name: platform-automation-tasks
    type: s3
    source:
      access_key_id: ((s3.access_key_id))
      secret_access_key: ((s3.secret_access_key))
      region_name: ((s3.region_name))
      bucket: ((s3.buckets.pivnet_products))
      regexp: .*tasks-(.*).zip

  - name: platform-automation-image
    type: s3
    source:
      access_key_id: ((s3.access_key_id))
      secret_access_key: ((s3.secret_access_key))
      region_name: ((s3.region_name))
      bucket: ((s3.buckets.pivnet_products))
      regexp: .*image-(.*).tgz
      
  - name: configuration
    type: git
    source:
      private_key: ((configuration.private_key))
      uri: ((configuration.uri))
      branch: master
```

In our `jobs` section, we need a job that will interpolate the env file, pull down the 
Ops Manager director config, and store the director config in the configuration directory
(this can be the same resource as where the env is located, but will be stored in the `config`
instead of the `env` directory). In order to persist the director config in your git repo,
we first need to make a commit, detailing the change we made, and where in your git repo the 
change happened. A way to do this is shown below:

```yaml
jobs:
  - name: staged-director-config
    plan:
      - aggregate:
          - get: platform-automation-tasks
            params: {unpack: true}
          - get: platform-automation-image
            params: {unpack: true}
          - get: configuration
      - task: interpolate-env-creds
        image: platform-automation-image
        file: platform-automation-tasks/tasks/credhub-interpolate.yml
        params:
          CREDHUB_CLIENT: ((credhub-client))
          CREDHUB_SECRET: ((credhub-secret))
          CREDHUB_SERVER: ((credhub-server))
          PREFIX: '/pipeline/vsphere'
          INTERPOLATION_PATH: ((foundation))/config
          SKIP_MISSING: true
        input_mapping:
          files: configuration
        output_mapping:
          interpolated-files: interpolated-configs
      - task: staged-director-config
        image: platform-automation-image
        file: platform-automation-tasks/tasks/staged-director-config.yml
        input_mapping:
          env: interpolated-env
        output_mapping:
          generated-config: configuration/((foundation))/config
        params:
          ENV_FILE: ((foundation))/env/env.yml
      - task: make-commit
        image: platform-automation-image
        file: platform-automation-tasks/tasks/make-git-commit.yml
        input_mapping:
          repository: configuration
          file-source: configuration/((foundation))/config
        output_mapping:
          repository-commit: configuration-commit
        params:
          FILE_SOURCE_PATH: director.yml
          FILE_DESTINATION_PATH: config/((foundation))/director.yml
          GIT_AUTHOR_EMAIL: "git-author-email@example.com"
          GIT_AUTHOR_NAME: "Git Author"
          COMMIT_MESSAGE: "Update director.yml file"
      - put: configuration
        params:
          repository: configuration-commit
          merge: true
```

### Retrieving Existing Product Configurations

If you would like to automate the configuration of your product tiles, you first need to externalize
each product's configuration. Using Platform Automation, this is done using Docker or by adding a job to
the pipeline.

**Docker**

As an example, we are going to start with the PAS tile.
To get the currently configured PAS configuration, we have to:

1. Import the image
```bash
docker import ${PLATFORM_AUTOMATION_IMAGE_TGZ} platform-automation-image
```
Where `${PLATFORM_AUTOMATION_IMAGE_TGZ}` is the image file downloaded from Pivnet.

2. Then, you can use `docker run` to pass it arbitrary commands.
Here, we're running the `om` CLI to see what commands are available:
```bash
docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
om -h
```

Note:  that this will have access read and write files in your current working directory.
If you need to mount other directories as well, you can add additional `-v` arguments.

The command we will use to extract the current director configuration is called 
[`staged-config`][staged-config]. This is an `om` command that calls
the Ops Manager API to pull down the currently configured product configuration given
a product slug. To run this using Docker, you will need the env file created above as ${ENV_FILE}.
The product slug for the PAS tile, within Ops Manager, is `cf`. To find the slug of your
product, you can run the following docker command:

```bash
docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
om --env ${ENV_FILE} staged-products
```

This will give you a table like the following:

```
+---------------+-----------------+
|     NAME      |     VERSION     |
+---------------+-----------------+
| cf            | 2.x.x           |
| p-healthwatch | 1.x.x-build.x   |
| p-bosh        | 2.x.x-build.x   |
+---------------+-----------------+
```

The values in the `NAME` column are the slugs of each product you have deployed. For this
_How to Guide_, we only have PAS and Healthwatch. 

!!! info 
    p-bosh is the product slug of Ops Manager. However, `staged-config` _**cannot**_ 
    be used to extract the director config. To do so, you must use `staged-director-config`


With the appropriate product `${SLUG}`, we can run the following docker command to pull down
the configuration of the chosen tile:
```bash
docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
om --env ${ENV_FILE} staged-config --product-name ${SLUG} --include-placeholders
```

`--include-placeholders` is an optional flag, but highly recommended if you want a full
configuration for your tile. This flag will replace any fields marked as "secret" 
by the product in the config with ((parametrized)) variables. If you would prefer to not
work with ((parametrized)) variables, you can substitute `--include-placeholders` with
`--include-credentials`.
 
!!! warning
    `--include-credentials` WILL expose passwords and 
    secrets in _plain text_. Therefore, `--include-placeholders` is recommended, but not required.

**Pipeline**

To add [`staged-config`] to your pipeline, you will need the following resources:

* the Platform Automation image
* the Platform Automation tasks
* a configuration path for your env file
* a resource to store the exported configuration into

Starting our Concourse pipeline, we need the following resources:
```yaml
resources:
  - name: platform-automation-tasks
    type: s3
    source:
      access_key_id: ((s3.access_key_id))
      secret_access_key: ((s3.secret_access_key))
      region_name: ((s3.region_name))
      bucket: ((s3.buckets.pivnet_products))
      regexp: .*tasks-(.*).zip

  - name: platform-automation-image
    type: s3
    source:
      access_key_id: ((s3.access_key_id))
      secret_access_key: ((s3.secret_access_key))
      region_name: ((s3.region_name))
      bucket: ((s3.buckets.pivnet_products))
      regexp: .*image-(.*).tgz
      
  - name: configuration
    type: git
    source:
      private_key: ((configuration.private_key))
      uri: ((configuration.uri))
      branch: master
```

In our `jobs` section, we need a job that will interpolate the env file, pull down the 
product config, and store the director config in the configuration directory
(this can be the same resource as where the env is located, but will be stored in the `config`
instead of the `env` directory). In order to persist the product config in your git repo,
we first need to make a commit, detailing the change we made, and where in your git repo the 
change happened. A way to do this is shown below:

```yaml
jobs:
  - name: staged-config
    plan:
      - aggregate:
          - get: platform-automation-tasks
            params: {unpack: true}
          - get: platform-automation-image
            params: {unpack: true}
          - get: configuration
      - task: interpolate-env-creds
        image: platform-automation-image
        file: platform-automation-tasks/tasks/credhub-interpolate.yml
        params:
          CREDHUB_CLIENT: ((credhub-client))
          CREDHUB_SECRET: ((credhub-secret))
          CREDHUB_SERVER: ((credhub-server))
          PREFIX: '/pipeline/vsphere'
          INTERPOLATION_PATH: ((foundation))/config
          SKIP_MISSING: true
        input_mapping:
          files: configuration
        output_mapping:
          interpolated-files: interpolated-configs
      - task: staged-config
        image: platform-automation-image
        file: platform-automation-tasks/tasks/staged-config.yml
        input_mapping:
          env: interpolated-env
        output_mapping:
          generated-config: configuration/((foundation))/config
        params:
          PRODUCT_NAME: cf   # this is the slug from `staged-products`
          ENV_FILE: ((foundation))/env/env.yml
      - task: make-commit
        image: platform-automation-image
        file: platform-automation-tasks/tasks/make-git-commit.yml
        input_mapping:
          repository: configuration
          file-source: configuration/((foundation))/config
        output_mapping:
          repository-commit: configuration-commit
        params:
          FILE_SOURCE_PATH: cf.yml  # the filename will be called ${SLUG}.yml
          FILE_DESTINATION_PATH: config/((foundation))/director.yml
          GIT_AUTHOR_EMAIL: "git-author-email@example.com"
          GIT_AUTHOR_NAME: "Git Author"
          COMMIT_MESSAGE: "Update director.yml file"
      - put: configuration
        params:
          repository: configuration-commit
          merge: true
```

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
 