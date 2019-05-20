---
title: Pipeline Reference
owner: PCF Platform Automation
---

Below you will find a reference pipeline that illustrates the tasks and provides an example of a basic pipeline design. You know your environment and constraints and we don't - we recommend you look at the tasks that make up the pipeline, and see how they can be arranged for your specific automation needs. For a deeper dive into each task see the Task Reference.

These Concourse pipelines are examples on how to use the [tasks](../reference/task.md). If you use a different CI/CD platform, you can use these Concourse files as examples of the inputs, outputs, and arguments used in each step in the workflow.

## Prerequisites

* Deployed Concourse

!!! info
    Platform Automation for PCF is based on Concourse CI.
    We recommend that you have some familiarity with Concourse before getting started.
    If you are new to Concourse, [Concourse CI Tutorials](https://docs.pivotal.io/p-concourse/3-0/guides.html) would be a good place to start.

* Persisted datastore that can be accessed by Concourse resource (e.g. s3, gcs, minio)
* A valid [generating-env-file]: this file will contain credentials necessary to login to Ops Manager using the `om` CLI.
It is used by every task within Platform Automation for PCF
* A valid [auth-file]: this file will contain the credentials necessary to create the Ops Manager login the first time
the VM is created. The choices for this file are simple or saml authentication.

!!! info
    There will be some crossover between the auth file and the env file due to how om is setup and how the system works. It is highly recommended to parameterize these values, and let a credential management system (such as Credhub) fill in these values for you in order to maintain consistency across files.

* An [opsman-configuration] file: This file is required to connect to an IAAS, and control the lifecycle management
 of the Ops Manager VM
* A [director-configuration] file: Each Ops Manager needs its own configuration, but it is retrieved differently from
a product configuration. This config is used to deploy a new Ops Manager director, or update an existing one.
* A set of valid [product-configuration] files: Each product configuration is a yaml file that contains the properties
necessary to configure an Ops Manager product using the `om` tool. This can be used during install or update.
* (Optional) A working [credhub] setup with its own UAA client and secret.


!!! info "Retrieving products from Pivnet"
    Please ensure products have been procured from Pivotal Network using the [reference-resources].

## Installing Ops Manager and a single product

The pipeline shows how to compose the tasks
to install Ops Manager and the PKS product.
Its dependencies are coming from a trusted git repository and S3,
which can be retrieved using [this pipeline][reference-resources].

## Pipeline Components

### S3 Resources

These can either be uploaded manually or from the [reference resources pipeline][reference-resources].

{% code_snippet 'examples', 'single-product-resources-s3' %}

### Exported Installation Resource

{% include "./.export_installation_note.md" %}

{% code_snippet 'examples', 'single-product-export-installation' %}

### Configured Resources

These contain values for
opsman vm creation, director, product, foundation-specific vars, auth, and env files.
For more details, see the [Inputs and Outputs][inputs-outputs] section.
Platform Automation will not create these resources for you.

{% code_snippet 'examples', 'single-product-resources-configurations' %}

### Trigger Resources

{% code_snippet 'examples', 'single-product-resources-triggers' %}

### Credhub Interpolate Job

`((foundation))` is a value
intended to be replaced by the filepath
of your foundation directory structure in github
(if you are not using multi-foundation, this value can be removed).

`((credhub-*))` are values for accessing your Concourse Credhub.
These are set when `fly`-ing your pipeline.
For more information on how to fly your pipeline
and use `((foundation))`,
please reference our How To Guides for your specific workflow.
Platform Automation will not create your Credhub or store values into your Credhub for you.

{% code_snippet 'examples', 'single-product-interpolate-creds' %}

### Jobs

Each job corresponds to a "box"
on the visual representation of your Concourse pipeline.
These jobs consume resources defined above.

{% code_snippet 'examples', 'single-product-jobs' %}


{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
