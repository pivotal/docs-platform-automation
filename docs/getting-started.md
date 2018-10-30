---
title: "Getting Started: Generating Configs and Inputs"
owner: PCF Platform Automation
---

##  Requirements

* Deployed Concourse
* Persisted datastore that can be accessed by Concourse resource (e.g. s3, gcs, minio)
* Pivnet access to [Platform Automation](https://network.pivotal.io/products/platform-automation/)

!!! note ""
     <strong>Note</strong>: The Platform Automation for PCF is based on Concourse CI, it is recommended that you have some familiarity with Conocurse before getting started. If you are new to Concourse, <a href="https://docs.pivotal.io/p-concourse/3-0/guides.html">Concourse CI Tutorials</a> would be a good place to start. 

* a valid [env file]: this file will contain credentials necessary to login to Ops Manager using the `om` CLI. 
It is used by every task within Platform Automation for PCF
* a valid [auth file]: this file will contain the credentials necessary to create the Ops Manager login the first time
the VM is created. The choices for this file are simple or saml authentication.

!!! note ""
     <strong>Note</strong>: There will be some crossover between the auth file and the env file due to how om is setup and how the system works. It is highly recommended to parameterize these values, and let a credential management system (such as Credhub) fill in these values for you in order to maintain consistency across files. 

* a [opsmanager configuration] file: This file is required to connect to an IAAS, and control the lifecycle management
 of the Ops Manager VM
* a [director configuration] file: Each Ops Manager needs its own configuration, but it is retrieved differently from
a product configuration. This config is used to deploy a new Ops Manager director, or update an existing one. 
* a set of valid [product configuration] files: Each product configuration is a yaml file that contains the properties
necessary to configure an Ops Manager product tile using the `om` tool. This can be used during install or update. 
* (Optional) a working [credhub] setup with its own UAA client and secret.

##  Setup

1. Download the latest version of [Platform Automation](https://network.pivotal.io/products/platform-automation/) from Pivnet.
   You will need:
   * `Concourse Tasks`
   * `Docker Image for Concourse Tasks`

!!! note ""
     <strong>Note</strong>: If the pivnet link does not work for you, you might not have access to the product! Please communicate this in the #pcf-automation slack channel until the project is GA 

1. Store the `platform-automation-image-*.tgz` in a blobstore that can be accessed via a Concourse pipeline.

1. Store the `platform-automation-tasks-*.zip` in a blobstore that can be accessed via a Concourse pipeline.

1. Next we'll create a test pipeline to see if the assets can be accessed correctly.
   This pipeline runs a test task, which ensures that all the parts work correctly. 
   (the example pipeline assumes s3 as the blobstore)
   
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

Fill in the S3 resource credentials and set the above pipeline on your Concourse instance.

!!! note ""
     <strong>Note</strong>: The pipeline can use any blobstore. We choose S3 because the resource natively supported by Concourse. S3 resource also supports S3-compatible blobstores (e.g. minio). See <a href="https://github.com/concourse/s3-resource#source-configuration">S3 Resource</a> for more information. If you want to use other blobstore, you need to provide a custom <a href="https://concourse-ci.org/resource-types.html">resource type</a> . 

## Generating an Env File
Almost all [`om`][om] commands require an env file
to hit authenticated API endpoints.

The configuration for authentication has a dependency on either username/password

{% code_snippet 'pivotal/platform-automation', 'env' %}

or, if using SAML, a client-id and client-secret.

{% code_snippet 'pivotal/platform-automation', 'env-uaa' %}

While `decryption-passphrase` is nominally optional,
if you intend to use a single `env.yml` for an entire pipeline,
it will be necessary to include for use with the `import-installation` step.

## Generating an Auth File
These configuration formats match the configuration for setting up authentication.
See the documentation for the [`configure-authentication`][configure-authentication]
or [`configure-saml-authentication`][configure-saml-authentication] task for details.

The configuration for authentication has a dependency on either username/password

{% code_snippet 'pivotal/platform-automation', 'auth-configuration' %}

or SAML configuration information.

{% code_snippet 'pivotal/platform-automation', 'saml-auth-configuration' %}

## Generating Director Configuration
To generate the configuration for an Ops Manager, you will need the following (Just like a tile):

1. a running Ops Manager
  - this is accomplished by running the following tasks:
      - [create-vm]
      - [configure-authentication] or [configure-saml-authentication]
      - [configure-director]
      - [apply-director-changes]

1. Configure Ops Manager _manually_ within the Ops Manager UI (Instructions for doing so can be found
using the [Official PCF Documentation])

1. Run the following command to get the staged config:

```bash
docker import ${PLATFORM_AUTOMATION_IMAGE_TGZ} pcf-automation-image
docker run -it --rm -v $PWD:/workspace -w /workspace pcf-automation-image \
om --env ${ENV_FILE} staged-director-config --include-placeholders
```

Where `${PLATFORM_AUTOMATION_IMAGE_TGZ}` is the image file downloaded from Pivnet, and `${ENV_FILE}` is the [env file] 
required for all tasks. The resulting file can then be parameterized, saved, and uploaded to a persistent 
blobstore(i.e. s3, gcs, azure blobstore, etc).

Alternatively, you can add the following task to your pipeline to generate and persist this for you:

{% code_snippet 'pivotal/platform-automation', 'staged-director-config' %}

!!! note ""
     <strong>Note</strong>: staged-director-config will not be able to grab all sensitive fields in your Ops Manager installation (for example: vcenter_username and vcenter_password if using vsphere). To find these missing fields, please refer to the <a href="https://docs.pivotal.io/pivotalcf/opsman-api/">Ops Manager API Documentation</a> 

## Generating Product Configuration
To generate the configuration for a tile, you will need the following:

1. a running Ops Manager
  - this is accomplished by running the following tasks:
      - [create-vm]
      - [configure-authentication] or [configure-saml-authentication]
      - [configure-director]
      - [apply-director-changes]
  
1. The tile you wish to have a config file for needs to be [uploaded and staged] in the Ops Manager
environment

1. Configure the tile _manually_ within the Ops Manager UI (Instructions for PAS can be found
using the [Official PCF Documentation])

1. Run the following command to get the staged config:

```bash
docker import ${PLATFORM_AUTOMATION_IMAGE_TGZ} pcf-automation-image
docker run -it --rm -v $PWD:/workspace -w /workspace pcf-automation-image \
om --env ${ENV_FILE} staged-config --product-name ${PRODUCT_SLUG} --include-credentials
```

Where `${PLATFORM_AUTOMATION_IMAGE_TGZ}` is the image file downloaded from Pivnet,and `${ENV_FILE}` is the [env file] required for all tasks, and `${PRODUCT_SLUG}` is the name of the product
downloaded from [pivnet]. The resulting file can then be parameterized, saved, and uploaded to a 
persistent blobstore(i.e. s3, gcs, azure blobstore, etc).

Alternatively, you can add the following task to your pipeline to generate and persist this for you:

{% code_snippet 'pivotal/platform-automation', 'staged-config' %}


##  Using Your Credhub
Credhub can be used to store secure properties that you don't want committed into a config file.
Within your pipeline, the config file can then reference that Credhub value for runtime evaluation.

An example workflow would be storing an SSH key.

1. Authenticate with your credhub instance.
2. Generate an ssh key: `credhub generate --name="/private-foundation/opsman_ssh_key" --type=ssh`
3. Create an [opsmanager configuration] file that references the name of the property.

```yaml
opsman-configuration:
  azure:
    ssh_public_key: ((opsman_ssh_key.public_key))
```

4. Configure your pipeline to use the [credhub interpolate](./task-reference.md#credhub-interpolate) task.
   It takes an input `files`, which should contain your configuration file from (3).
   
   The declaration within a pipeline might look like:
   
```yaml
jobs:
- name: example-job
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
```

Notice the `PREFIX` has been set to `/private-foundation`, the path prefix defined for your cred in (2).
This allows the config file to have values scoped, for example, per foundation.
`params` should be filled in by the credhub created with your Concourse instance.

This task will reach out to the deployed credhub and fill in your entry references and return an output
named `interpolated-files` that can then be read as an input to any following tasks. 

Our configuration will now look like

```yaml
opsman-configuration:
 azure:
   ssh_public_key: ssh-rsa AAAAB3Nz...
```

## Managing Configuration, Auth, and State Files
To use all these files with the Concourse tasks that require them,
you need to make them available as Concourse Resources.
They’re all text files, and there are many resource types that can work for this - in our examples,
we use git repository. As with the tasks and image,
you’ll need to upload them to a bucket and declare a resource in your pipeline for each file you need.

## Making Your Own Pipeline
If the example pipeline doesn’t work for you, that’s okay! It probably shouldn’t.
You know your environment and constraints, and we don’t.
We recommend you look at the tasks that make up the pipeline,
and see if they can be arranged such that they do what you need. 
If you have Platform Architects available, they can help you look at this problem.

Our example just illustrates the tasks and provides one possible starting place
- the suggested starting projects provide other starting places that make different choices.
Your pipeline is yours, not a fork of something we wrote.

If the tasks themselves don’t work for you, we’d like to hear from you.
We might be able to help you figure out how to make it work,
or we can use the feedback to improve the tasks so they’re a better fit for what you need.
If you need to write your own tasks in the meantime, our tasks are designed with clear interfaces,
and should be able to coexist in a pipeline with tasks from other sources, or custom tasks you develop yourself.

[apply-director-changes]: ./task-reference.md#apply-director-changes
[auth file]: ./getting-started.md#generating-an-auth-file
[configure-authentication]: ./task-reference.md#configure-authentication
[configure-director]: ./task-reference.md#configure-director
[concourse-documentation]: https://github.com/concourse/s3-resource
[configure-saml-authentication]: ./task-reference.md#configure-saml-authentication
[create-vm]: ./task-reference.md#create-vm
[credhub]: https://docs.pivotal.io/pivotalcf/credhub/
[director configuration]: ./getting-started.md#generating-director-configuration
[env file]: ./getting-started.md#generating-an-env-file
[Official PCF Documentation]: https://docs.pivotal.io/pivotalcf/installing/index.html
[om]: https://github.com/pivotal-cf/om
[opsmanager configuration]: ./task-reference.md#opsman-config
[pivnet]: https://network.pivotal.io
[product configuration]: ./getting-started.md#generating-product-configuration
[staged-config]: ./task-reference.md#staged-config
[staged-director-config]: ./task-reference.md#staged-director-config
[uploaded-and-staged]: ./task-reference.md#upload-and-stage-product
