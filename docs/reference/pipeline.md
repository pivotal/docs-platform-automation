---
title: Pipeline Reference
owner: PCF Platform Automation
---

##  Platform Automation for PCF Pipelines
These Concourse pipelines are examples
on how to use the [tasks](task.md).

###Making Your Own Pipeline###

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

###Prerequisites###

* Deployed Concourse

!!! note
    Platform Automation for PCF is based on Concourse CI.
    We recommend that you have some familiarity with Concourse before getting started.
    If you are new to Concourse, [Concourse CI Tutorials](https://docs.pivotal.io/p-concourse/3-0/guides.html) would be a good place to start.

* Persisted datastore that can be accessed by Concourse resource (e.g. s3, gcs, minio)
* Pivnet access to [Platform Automation][pivnet-platform-automation]
* A valid [env file]: this file will contain credentials necessary to login to Ops Manager using the `om` CLI.
It is used by every task within Platform Automation for PCF
* A valid [auth file]: this file will contain the credentials necessary to create the Ops Manager login the first time
the VM is created. The choices for this file are simple or saml authentication.

!!! note
    There will be some crossover between the auth file and the env file due to how om is setup and how the system works. It is highly recommended to parameterize these values, and let a credential management system (such as Credhub) fill in these values for you in order to maintain consistency across files.

* An [opsmanager configuration] file: This file is required to connect to an IAAS, and control the lifecycle management
 of the Ops Manager VM
* A [director configuration] file: Each Ops Manager needs its own configuration, but it is retrieved differently from
a product configuration. This config is used to deploy a new Ops Manager director, or update an existing one.
* A set of valid [product configuration] files: Each product configuration is a yaml file that contains the properties
necessary to configure an Ops Manager product tile using the `om` tool. This can be used during install or update.
* (Optional) A working [credhub] setup with its own UAA client and secret.


## Retrieving external dependencies

The pipeline downloads dependencies consumed by the tasks
and places them into a trusted s3-like storage provider.
This helps other concourse deployments without internet access
retrieve task dependencies.

{% code_snippet 'pivotal/platform-automation', 'put-resources-pipeline' %}

## Installing Ops Manager and tiles

The pipeline shows how compose the tasks to install Ops Manager and the PCF and Healthwatch tiles.
Its dependencies are coming from a trusted git repository,
which can be retrieved using [this pipeline](#retrieving-external-dependencies).

{% code_snippet 'pivotal/platform-automation', 'pipeline' %}

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
