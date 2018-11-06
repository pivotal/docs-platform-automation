---
title: Platform Automation for PCF
owner: PCF Platform Automation
---

!!! warning 
    The Platform Automation for Pivotal Cloud Foundry (PCF) is currently in alpha and is intended for evaluation and test purposes only. 

Platform Automation for Pivotal Cloud Foundry (PCF)
is a set of tasks that wrap and extend [om][om],
a command-line interface to Ops Manager.

Platform Automation for PCF uses `om`,
(and by extension, the Ops Manager API)
to enable command-line interaction with Ops Manager,
a dashboard for installing, configuring, and updating software products on PCF.
Platform Automation for PCF comes bundled with Concourse tasks
that demonstrate how to use these tasks
in a containerized Continuous Integration (CI) system,
and a reference pipeline
showing one possible configuration of these tasks.

To learn more about Ops Manager,
see [Understanding the Ops Manager Interface][understanding-opsman].

## Overview
Platform Automation for PCF commands enable PCF operators
to script and automate Ops Manager actions.
Platform Automation for PCF commands are:

* **Legible**: They use configuration from
human-readable YAML files,
which users can edit,
and manage in version control.

* **Modular**: Each command has defined inputs and outputs
and performs a granular action.
They're designed to work together
to enable many different workflows.
Users can build systems to make changes to all their products together,
or one at a time.
Users can extract configuration from one environment
and use it as a template for configuring many more.

* **Built for Automation** Commands are idempotent,
so re-running them in a CI won't break builds.
They read and write config from files,
which machines can easily pass around.
They're available in a Docker container,
which makes the tools easy to use in CI.

* **Not Comprehensive**: Workflows that use Platform Automation for PCF
typically also contain `om` commands, custom tasks,
and even interactions with the Ops Manager user interface.
Platform Automation for PCF is a set of tools to use alongside other tools,
rather than a comprehensive solution.

## What do I need to understand up front?
If you’ve just downloaded Platform Automation for PCF,
it will be helpful to understand some things before you get started.
We recommend you read over this whole document before you dive into anything.

Platform Automation for PCF is a collection of tools and documentation.
It’s not a simple solution that can be “installed.”
It is intended to facilitate operator-owned automation
of both common and advanced workflows around Pivotal Ops Manager.
Ultimately, the resulting automation is a product of the operator.

Platform Automation for PCF is principally designed
to help operators create Concourse pipelines that suit their needs.
This means you’ll need Concourse deployed, and that you’ll need to setup some Concourse resources.

While Platform Automation for PCF _can_ deploy an Ops Manager VM, it doesn’t _have to_.
You can use it to automate an Ops Manager you already have.

There was a beta product from Pivotal called
“PCF Platform Automation with Concourse (PCF Pipelines)”.
It was never made publicly available and is deprecated.
If your current pipeline is based on PCF Pipelines,
we recommend building a replacement pipeline with the new tooling,
as opposed to trying to modify your existing pipeline to use the new tools.
Since Platform Automation for PCF can easily take over management of an existing Ops Manager,
this should be fairly straightforward.
Still, we may offer more detailed documentation support for this specific workflow in the future,
and would like to hear from you if you feel that would be helpful.

##  Using Platform Automation for PCF in Pipelines
Platform Automation for PCF comes bundled with Concourse [tasks][concourse-task-definition].
These task files wrap one or two Platform Automation for PCF commands
and their input and output definitions
in the YAML format that Concourse uses to build pipelines.
If you use a different CI/CD platform, you can use these Concourse files as examples
of the inputs, outputs, and arguments used in each step in the workflow.

The [Getting Started][getting-started] topic is a great place to start.

The [Task Reference][task-reference] topic discusses these example tasks further.

[task-reference]: reference/task.md
[concourse-task-definition]: https://concourse-ci.org/tasks.html
[getting-started]: ./getting-started.md
[om]: https://github.com/pivotal-cf/om
[understanding-opsman]: http://docs.pivotal.io/pivotalcf/customizing/pcf-interface.html
