---
title: Pipeline Reference
---

Below you will find a reference pipeline that illustrates the tasks and provides an example of a basic pipeline design. You know your environment and constraints and we don't - we recommend you look at the tasks that make up the pipeline, and see how they can be arranged for your specific automation needs. For a deeper dive into each task see the Task Reference.

These Concourse pipelines are examples on how to use the [tasks](../reference/task.md). If you use a different CI/CD platform, you can use these Concourse files as examples of the inputs, outputs, and arguments used in each step in the workflow.

## Prerequisites

* Deployed Concourse

!!! info
    Pivotal Platform Automation is based on Concourse CI.
    We recommend that you have some familiarity with Concourse before getting started.
    If you are new to Concourse, [Concourse CI Tutorials](https://docs.pivotal.io/p-concourse/3-0/guides.html) would be a good place to start.

* Persisted datastore that can be accessed by Concourse resource (e.g. s3, gcs, minio)
* Pivnet access to [Platform Automation][pivnet-platform-automation]
* A set of valid [download-product-config][download-product-config] files: Each product has a configuration YAML of what version to download from Pivotal Network.

## Retrieval from Pivotal Network

{% include "./.opsman_filename_change_note.md" %}

The pipeline downloads dependencies consumed by the tasks
and places them into a trusted s3-like storage provider.
This helps other concourse deployments without internet access
retrieve task dependencies.

!!! tip "S3 filename prefixing"
    Note the unique regex format for blob names,
    for example: `\[p-healthwatch,(.*)\]p-healthwatch-.*.pivotal`.
    Pivnet filenames will not always contain the necessary metadata
    to accurately download files from S3.
    So, the product slug and version are prepended when using `download-product`.
    For more information on how this works,
    and what to expect when using `download-product` and `download-product-s3`,
    refer to the [`download-product` task reference.][download-product]

The pipeline requires configuration for the [download-product](../reference/task.md#download-product) task.
Below are examples that can be used.

``` yaml tab="Healthwatch"
{% include './examples/download-product-configs/healthwatch.yml' %}
```

``` yaml tab="Pivotal Application Service"
{% include './examples/download-product-configs/pas.yml' %}
```

``` yaml tab="Pivotal Application Service Windows"
{% include './examples/download-product-configs/pas-windows.yml' %}
```

``` yaml tab="OpsMan"
{% include './examples/download-product-configs/opsman.yml' %}
```

``` yaml tab="Pivotal Container Service"
{% include './examples/download-product-configs/pks.yml' %}
```

## Pipeline Components

### Resource Types

This custom resource type uses the pivnet resource
to pull down and separate both pieces of the Platform Automation product (tasks and image)
so they can be stored separately in S3.

{% code_snippet 'examples', 'resources-pipeline-resource-types' %}

### Product Resources

S3 resources where Platform Automation [`download-product`][download-product] outputs will be stored.
Each product/stemcell needs a separate resource defined.
Platform Automation will not create these resources for you.

{% code_snippet 'examples', 'resources-pipeline-products' %}

### Platform Automation Resources

`platform-automation-pivnet` is downloaded directly from Pivnet
and will be used to download all other products from Pivnet.

`platform-automation-tasks` and `platform-automation-image` are S3 resources
that will be stored for internet-restricted, or faster, access.
Platform Automation will not create this resource for you.

{% code_snippet 'examples', 'resources-pipeline-platform-automation' %}

### Configured Resources

You will need to add your [`download-product` configuration][download-product-config] configuration files
to your configurations repo.
Platform Automation will not create these resources for you.
For more details, see the [Inputs and Outputs][inputs-outputs] section.

{% code_snippet 'examples', 'resources-pipeline-configurations' %}

### Trigger Resources

{% code_snippet 'examples', 'resources-pipeline-triggers' %}

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

{% code_snippet 'examples', 'resources-pipeline-interpolate-creds' %}

### Jobs

Each job corresponds to a "box" on the visual representation of your Concourse pipeline.
These jobs consume resources defined above.

{% code_snippet 'examples', 'resources-pipeline-jobs' %}

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
