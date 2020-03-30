Below you will find a reference pipeline that illustrates the tasks and provides an example of a basic pipeline design. You know your environment and constraints and we don't - we recommend you look at the tasks that make up the pipeline, and see how they can be arranged for your specific automation needs. For a deeper dive into each task see the Task Reference.

These Concourse pipelines are examples on how to use the [tasks](../tasks.md). If you use a different CI/CD platform, you can use these Concourse files as examples of the inputs, outputs, and arguments used in each step in the workflow.

## Prerequisites

* Deployed Concourse

!!! info
    Platform Automation Toolkit is based on Concourse CI.
    We recommend that you have some familiarity with Concourse before getting started.
    If you are new to Concourse, [Concourse CI Tutorials][concourse-tutorial] would be a good place to start.

* Persisted datastore that can be accessed by Concourse resource (e.g. s3, gcs, minio)
* A set of valid [download-product-config][download-product-config] files: Each product has a configuration YAML of what version to download from Tanzu Network.
* Tanzu Network access to [Platform Automation Toolkit][tanzu-network-platform-automation]

## Retrieval from Tanzu Network

{% include "./.opsman_filename_change_note.md" %}

The pipeline downloads dependencies consumed by the tasks
and places them into a trusted s3-like storage provider.
This helps other concourse deployments without internet access
retrieve task dependencies.

!!! tip "Blobstore filename prefixing"
    Note the unique regex format for blob names,
    for example: `\[p-healthwatch,(.*)\]p-healthwatch-.*.pivotal`.
    Tanzu Network filenames will not always contain the necessary metadata
    to accurately download files from a blobstore (i.e. s3, gcs, azure).
    So, the product slug and version are prepended when using `download-product`.
    For more information on how this works,
    and what to expect when using `download-product`,
    refer to the [`download-product` task reference.][download-product]

The pipeline requires configuration for the [download-product](../tasks.md#download-product) task.
Below are examples that can be used.

{% code_snippet 'reference', 'download-healthwatch-from-pivnet-usage', 'Healthwatch' %}
{% code_snippet 'reference', 'download-ops-manager-from-pivnet-usage', 'Ops Manager' %}
{% code_snippet 'reference', 'download-pks-from-pivnet-usage', 'PKS' %}
{% code_snippet 'reference', 'download-tas-from-pivnet-usage', 'TAS' %}
{% code_snippet 'reference', 'download-tas-windows-from-pivnet-usage', 'TAS Windows' %}

## Pipeline Components

### Resource Types

This custom resource type uses the [pivnet-resource][pivnet-resource]
to pull down and separate both pieces of the Platform Automation Toolkit product (tasks and image)
so they can be stored separately in S3.

{% code_snippet 'reference', 'resources-pipeline-resource-types' %}

### Product Resources

S3 resources where Platform Automation Toolkit [`download-product`][download-product] outputs will be stored.
Each product/stemcell needs a separate resource defined.
Platform Automation Toolkit will not create these resources for you.

{% code_snippet 'reference', 'resources-pipeline-products' %}

### Platform Automation Toolkit Resources

`platform-automation-pivnet` is downloaded directly from Tanzu Network
and will be used to download all other products from Tanzu Network.

`platform-automation-tasks` and `platform-automation-image` are S3 resources
that will be stored for internet-restricted, or faster, access.
Platform Automation Toolkit will not create this resource for you.

{% code_snippet 'reference', 'resources-pipeline-platform-automation' %}

### Configured Resources

You will need to add your [`download-product` configuration][download-product-config] configuration files
to your configurations repo.
Platform Automation Toolkit will not create these resources for you.
For more details, see the [Inputs and Outputs][inputs-outputs] section.

{% code_snippet 'reference', 'resources-pipeline-configurations' %}

### Trigger Resources

{% code_snippet 'reference', 'resources-pipeline-triggers' %}

### Secrets Handling

This helps load secrets stored in an external credential manager -- such as Credhub.
Concourse supports several [credential managers][concourse-secrets-handling] natively.
 
The configuration below uses the [`prepare-tasks-with-secrets`][prepare-tasks-with-secrets] task
to load secrets from your external configuration files.

{% code_snippet 'reference', 'resources-pipeline-prepare-tasks-with-secrets' %}

### Jobs

Each job corresponds to a "box" on the visual representation of your Concourse pipeline.
These jobs consume resources defined above.

{% code_snippet 'reference', 'resources-pipeline-jobs' %}

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
