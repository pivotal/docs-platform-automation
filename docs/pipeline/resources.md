---
title: Pipeline Reference
owner: PCF Platform Automation
---

!!! info 
    These Concourse pipelines are examples
    on how to use the [tasks](../reference/task.md). 
    If you use a different CI/CD platform, you can use these Concourse files as examples
    of the inputs, outputs, and arguments used in each step in the workflow.

## Making Your Own Pipeline

If the reference pipeline doesn’t work for you, that’s okay! It probably shouldn’t.
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

## Prerequisites

* Deployed Concourse

!!! info
    Platform Automation for PCF is based on Concourse CI.
    We recommend that you have some familiarity with Concourse before getting started.
    If you are new to Concourse, [Concourse CI Tutorials](https://docs.pivotal.io/p-concourse/3-0/guides.html) would be a good place to start.

* Persisted datastore that can be accessed by Concourse resource (e.g. s3, gcs, minio)
* Pivnet access to [Platform Automation][pivnet-platform-automation]
* A set of valid [download-product-config] files: Each product has a configuration YAML of what version to download from Pivotal Network. 

## Retrieval from Pivotal Network

{% include "./.opsman_filename_change_note.md" %}

The pipeline downloads dependencies consumed by the tasks
and places them into a trusted s3-like storage provider.
This helps other concourse deployments without internet access
retrieve task dependencies.

{% code_snippet 'examples', 'put-resources-pipeline' %}

This pipeline requires configuration for the [download-product](../reference/task.md#download-product) task.
Below are examples that can be used.

``` yaml tab="Healthwatch"
{% include './examples/download-product-configs/healthwatch.yml' %}
```

``` yaml tab="PAS"
{% include './examples/download-product-configs/pas.yml' %}
```

``` yaml tab="PAS Windows"
{% include './examples/download-product-configs/pas-windows.yml' %}
```

``` yaml tab="OpsMan"
{% include './examples/download-product-configs/opsman.yml' %}
```

``` yaml tab="PKS"
{% include './examples/download-product-configs/pks.yml' %}
```

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
