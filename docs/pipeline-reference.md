---
title: Platform Automation for PCF Pipeline Reference
owner: PCF Platform Automation
---

##  Platform Automation for PCF Pipelines
These Concourse pipelines are examples
on how to use the [tasks](task-reference.md).


### Retrieving external dependencies

The pipeline downloads dependencies consumed by the tasks
and places them into a trusted s3-like storage provider.
This helps other concourse deployments without internet access
retrieve task dependencies.

{% code_snippet 'pivotal/platform-automation', 'put-resources-pipeline' %}

### Installing Ops Manager and tiles

The pipeline shows how compose the tasks to install Ops Manager and the PCF and Healthwatch tiles.
Its dependencies are coming from a trusted git repository,
which can be retrieved using [this pipeline](#retrieving-external-dependencies).

{% code_snippet 'pivotal/platform-automation', 'pipeline' %}
