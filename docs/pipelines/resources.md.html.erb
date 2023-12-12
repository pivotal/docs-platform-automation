# Retrieving external dependencies

Below you will find a reference pipeline that illustrates the tasks and provides an example of a basic pipeline design. You know your environment and constraints and we don't - we recommend you look at the tasks that make up the pipeline, and see how they can be arranged for your specific automation needs. For a deeper dive into each task see the Task Reference.

These Concourse pipelines are examples on how to use the [tasks](../tasks.md). If you use a different CI/CD platform, you can use these Concourse files as examples of the inputs, outputs, and arguments used in each step in the workflow.

## Prerequisites

* Deployed Concourse

<p class="note">
<span class="note__title">Note</span>
Platform Automation Toolkit is based on Concourse CI.
We recommend that you have some familiarity with Concourse before getting started.
If you are new to Concourse, [Installing Concourse with BOSH](https://docs.vmware.com/en/Concourse-for-VMware-Tanzu/7.0/vmware-tanzu-concourse/GUID-installation-install-concourse-bosh.html) would be a good place to start.</p>

* Persisted datastore that can be accessed by Concourse resource (e.g. s3, gcs, minio)
* A set of valid [download-product-config](../pipelines/multiple-products.md#download-product-config) files: Each product has a configuration YAML of what version to download from [Tanzu Network](https://network.pivotal.io/).
* Tanzu Network access to [Platform Automation Toolkit](https://network.pivotal.io/products/platform-automation/)

## Retrieval from Tanzu Network

The pipeline downloads dependencies consumed by the tasks
and places them into a trusted s3-like storage provider.
This helps other concourse deployments without internet access
retrieve task dependencies.

<p class="note important">
<span class="note__title">Important</span>
Blobstore filename prefixing:
Note the unique regex format for blob names,
for example: <code>\[p-healthwatch,(.*)\]p-healthwatch-.*.pivotal</code>.
Tanzu Network filenames will not always contain the necessary metadata
to accurately download files from a blobstore (i.e., s3, gcs, azure).
So, the product slug and version are prepended when using `download-product`.
For more information on how this works,
and what to expect when using `download-product`,
see the <a href="../tasks.md#download-product"><code>download-product</code> task reference</a></p>

The pipeline requires configuration for the [download-product](../tasks.md#download-product) task.
Below are examples that can be used.

=== "Healthwatch"
     ---excerpt--- "reference/download-healthwatch-from-pivnet-usage"
=== "Ops Manager"
    ---excerpt--- "reference/download-ops-manager-from-pivnet-usage"
=== "PKS"
    ---excerpt--- "reference/download-pks-from-pivnet-usage"
=== "TAS"
    ---excerpt--- "reference/download-tas-from-pivnet-usage"


### Full Pipeline and Reference Configurations

There is a [git repository](https://github.com/pivotal/docs-platform-automation-reference-pipeline-config)
containing containing the [full pipeline file](https://github.com/pivotal/docs-platform-automation-reference-pipeline-config/blob/develop/pipelines/download-products.yml),
along with other pipeline and configuration examples.

This can be useful when you want to take
a fully assembled pipeline as a starting point;
the rest of this document covers the sections of the full pipeline in more detail.

## Pipeline components

### Resource types

This custom resource type uses the [pivnet-resource](https://github.com/pivotal-cf/pivnet-resource)
to pull down and separate both pieces of the Platform Automation Toolkit product (tasks and image)
so they can be stored separately in S3.

---excerpt--- "reference/resources-pipeline-resource-types"

### Product resources

S3 resources where Platform Automation Toolkit [`download-product`](../tasks.md#download-product]) outputs will be stored.
Each product/stemcell needs a separate resource defined.
Platform Automation Toolkit will not create these resources for you.

---excerpt--- "reference/resources-pipeline-products"

### Platform Automation Toolkit resources

`platform-automation-pivnet` is downloaded directly from Tanzu Network
and will be used to download all other products from Tanzu Network.

`platform-automation-tasks` and `platform-automation-image` are S3 resources
that will be stored for internet-restricted, or faster, access.
Platform Automation Toolkit will not create this resource for you.

---excerpt--- "reference/resources-pipeline-platform-automation"

### Configured resources

You will need to add your [`download-product` configuration](../inputs-outputs.md#download-product-config) files
to your configurations repo.
Platform Automation Toolkit will not create these resources for you.
For more details, see the [Inputs and outputs](../inputs-outputs.md) section.

---excerpt--- "reference/resources-pipeline-configurations"

### Trigger resources

---excerpt--- "reference/resources-pipeline-triggers"

### Secrets handling

This helps load secrets stored in an external credential manager such as CredHub.
Concourse supports several [credential managers](https://concourse-ci.org/creds.html) natively.
 
The configuration below uses the [`prepare-tasks-with-secrets`](../tasks.md#prepare-tasks-with-secrets) task
to load secrets from your external configuration files.

---excerpt--- "reference/resources-pipeline-prepare-tasks-with-secrets"

### Jobs

Each job corresponds to a "box" on the visual representation of your Concourse pipeline.
These jobs consume resources defined above.

---excerpt--- "reference/resources-pipeline-jobs"

[//]: # ({% with path="../" %})
[//]: # (    {% include ".internal_link_url.md" %})
[//]: # ({% endwith %})
[//]: # ({% include ".external_link_url.md" %})
