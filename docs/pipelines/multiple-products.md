# VMware Tanzu Operations Manager and multiple products

Below you will find a reference pipeline that illustrates the tasks and provides an example of a basic pipeline design. You know your environment and constraints and we don't - we recommend you look at the tasks that make up the pipeline, and see how they can be arranged for your specific automation needs. For a deeper dive into each task see the Task Reference.

These Concourse pipelines are examples on how to use the [tasks](../tasks.md). If you use a different CI/CD platform, you can use these Concourse files as examples of the inputs, outputs, and arguments used in each step in the workflow.

## Prerequisites

* Deployed Concourse

!!! info
    Platform Automation Toolkit is based on Concourse CI.
    We recommend that you have some familiarity with Concourse before getting started.
    If you are new to Concourse, [Concourse CI Tutorials][concourse-tutorial] would be a good place to start.

* Persisted datastore that can be accessed by Concourse resource (e.g. s3, gcs, minio)
* A valid [generating-env-file][generating-env-file]: this file will contain credentials necessary to login to Tanzu Operations Manager using the `om` CLI.
It is used by every task within Platform Automation Toolkit
* A valid [auth-file][auth-file]: this file will contain the credentials necessary to create the Tanzu Operations Manager login the first time
the VM is created. The choices for this file are simple or saml authentication.

!!! info
    There will be some crossover between the auth file and the env file due to how om is setup and how the system works. It is highly recommended to parameterize these values, and let a credential management system (such as Credhub) fill in these values for you in order to maintain consistency across files.

* An [opsman-configuration][opsman-config] file: This file is required to connect to an IAAS, and control the lifecycle management
 of the Tanzu Operations Manager VM
* A [director-configuration][director-configuration] file: Each Tanzu Operations Manager needs its own configuration, but it is retrieved differently from
a product configuration. This config is used to deploy a new Tanzu Operations Manager director, or update an existing one.
* A set of valid [product-configuration][product-configuration] files: Each product configuration is a yaml file that contains the properties
necessary to configure an Tanzu Operations Manager product using the `om` tool. This can be used during install or update.
* (Optional) A working [credhub][credhub] setup with its own UAA client and secret.


!!! info "Retrieving products from Tanzu Network"
    Please ensure products have been procured from Tanzu Network using the [reference-resources][reference-resources].

## Installing Ops Manager and multiple products

The pipeline shows how to compose the tasks
to install Tanzu Operations Manager and the Tanzu Application Service and Healthwatch products.
Its dependencies are coming from a trusted git repository,
which can be retrieved using [this pipeline][reference-resources].

### Full Pipeline and Reference Configurations

There is a [git repository][ref-config-repo]
containing containing the [full pipeline file][ref-config-pipeline],
along with other pipeline and configuration examples.

This can be useful when you want to take
a fully assembled pipeline as a starting point;
the rest of this document covers the sections of the full pipeline in more detail.

## Pipeline Components

### S3 Resources

These can either be uploaded manually or from the [reference resources pipeline][reference-resources].

---excerpt--- "reference/reference-resources-s3"
  
!!! tip "Tanzu Application Service-Windows with S3"
    If retrieving `pas-windows` and `pas-windows-stemcell` from an S3 bucket,
    you must use the built in S3 concourse resource.
    This is done in the example above.
    The `download-product` task with `SOURCE: s3` does not persist meta information 
    about necessary stemcell for `pas-windows`
    because VMware does not distribute the Window's file system. 
    
Alternatively, products may be downloaded using the `download-product` task with
the param `SOURCE` set to `s3|azure|gcs`.
In a job, specify the following task:

```yaml
...
- task: download-pas
  image: platform-automation-image
  file: platform-automation-tasks/tasks/download-product.yml
  params:
    CONFIG_FILE: download-product-configs/pas.yml
    SOURCE: s3
  input_mapping:
    config: interpolated-creds
  output_mapping:
    downloaded-product: pas-product
    downloaded-stemcell: pas-stemcell
...
```

### Exported Installation Resource

{% include "./.export_installation_note.md" %}

---excerpt--- "reference/export-installation-resource-usage"

### Configured Resources

These contain values for
opsman VM creation, director, product, foundation-specific vars, auth, and env files.
For more details, see the [Inputs and Outputs][inputs-outputs] section.
Platform Automation Toolkit will not create these resources for you.

---excerpt--- "reference/resources-configurations"

### Trigger Resources

---excerpt--- "reference/resources-triggers"

### Secrets Handling

This helps load secrets stored in an external credential manager -- such as Credhub.
Concourse support several [credential managers][concourse-secrets-handling] natively.
 
The configuration below uses the [`prepare-tasks-with-secrets`][prepare-tasks-with-secrets] task
to load secrets from your external configuration files.

---excerpt--- "reference/prepare-tasks-with-secrets-usage"

### Jobs

Each job corresponds to a "box"
on the visual representation of your Concourse pipeline.
These jobs consume resources defined above.

---excerpt--- "reference/reference-jobs"

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
