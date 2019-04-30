---
title: Platform Automation for PCF
owner: PCF Platform Automation
---

Platform Automation for PCF provides the building blocks to create a repeatable and reusable automated pipeline(s) for upgrading and installing PCF foundations.

In this introduction we'll cover:

* About Platform Automation
* Platform Automation and Ops Manager
* How to download and test the setup of Platform Automation  

## About

* Platform Automation for PCF uses [om][om],
(and by extension, the Ops Manager API)
to enable command-line interaction with Ops Manager
([Understanding the Ops Manager Interface][pivotalcf-understanding-opsman])
* Platform Automation for PCF includes a documented reference pipeline
showing one possible configuration to use tasks
* Platform Automation for PCF comes bundled with Concourse [tasks][concourse-task-definition]
that demonstrate how to use these tasks
in a containerized Continuous Integration (CI) system. Platform Automation for PCF tasks are:

    * Legible: They use
human-readable YAML config files which can be edited and managed

    * Modular: Each task has defined inputs and outputs
that perform granular actions

    * Built for Automation: Tasks are idempotent,
so re-running them in a CI won't break builds

    * Not Comprehensive: Workflows that use Platform Automation for PCF
may also contain `om` commands, custom tasks,
and even interactions with the Ops Manager user interface.
Platform Automation for PCF is a set of tools to use alongside other tools,
rather than a comprehensive solution.

The [Task Reference][task-reference] topic discusses these example tasks further.


!!! info "Transitioning from PCF Pipelines"
    If your current pipeline is based on PCF Pipelines,
    we recommend building a replacement pipeline with the new tooling,
    as opposed to trying to modify your existing pipeline to use the new tools. There is more upfront learning and set-up but in the long term you will have less maintenance with upgrades.


The following table compares how Ops Manager
and Platform Automation for PCF might run a typical sequence of PCF operations:

<table border="1">
  <tr>
    <th></th>
    <th>Ops Manager</th>
    <th>Platform Automation for PCF</th>
  </tr><tr>
    <th>When to Use</th>
    <th>First install and minor upgrades</th>
    <th>Config changes and patch upgrades</th>
  </tr><tr>
    <th>1. Create Ops Manager VM</th>
    <td>Manually prepare IaaS and create Ops Manager VM</td>
    <td><code>create-vm</code></td>
  </tr><tr>
    <th>2. Configure Who Can Run Ops</th>
    <td>Manually configure internal UAA or external identity provider</td>
    <td><code>configure-authentication</code> or <code>configure-saml-authentication</code></td>
  </tr><tr>
    <th>3. Configure BOSH</th>
    <td>Manually configure BOSH Director</td>
    <td><code>configure-director</code> with settings saved from BOSH Director with same version</td>
  </tr><tr>
    <th>4. Add Products</th>
    <td>Click <strong>Import a Product</strong> to upload file, then <strong>+</strong> to add tile to Installation Dashboard</td>
    <td><code>upload-and-stage-product</code></td>
  </tr><tr>
    <th>5. Configure Products</th>
    <td>Manually configure products</td>
    <td><code>configure-product</code> with settings saved from tiles with same version</td>
  </tr><tr>
    <th>6. Deploy Products</th>
    <td>Click <strong>Apply Changes</strong></td>
    <td><code>apply-changes</code></td>
  </tr><tr>
    <th>7. Upgrade</th>
    <td>Manually export existing Ops Manager settings, power off the VM, then create a new, updated
    Ops Manager VM</td>
    <td><code>export-installation</code> then <code>upgrade-opsman</code></td>
  </tr>
</table>

## Upgrading with Platform Automation for PCF

Successful platform engineering teams know that a platform team that’s always up to date is critical for their business.
If they don’t stay up to date, they miss out on the latest platform features and the services that Pivotal delivers,
which means their development teams miss out too. By not keeping up to date, platforms could encounter security risks or
even application failures.

Pivotal offers regular updates for PCF, which ensures our customers have access to the latest security patches and new features.
For example, Pivotal releases security patches every six days on average.

!!! info
    Platform Automation for PCF is based on Concourse CI.
    We recommend that you have some familiarity with Concourse before getting started.
    If you are new to Concourse, [Concourse CI Tutorials](https://docs.pivotal.io/p-concourse/guides.html) would be a good place to start.

So how can a platform engineering team simplify the platform upgrade process?

**Small and Constant Upgrades**

Adopting the best practice of small and constant platform updates is one of the best ways to simplify the platform
upgrade process. This behavior can significantly reduce risk, increase stability with faster troubleshooting, and
overall reduce the effort of upgrading. This also creates a culture of continuous iteration and improves feedback loops
with the platform teams and the developers - building trust across the organization. A good place start is by consuming every patch.

**How Platform Automation for PCF can help with small and continuous upgrades**

With Platform Automation for PCF, platform teams have the tools to create an automated perpetual upgrade machine that
can continuously take the latest updates when new software is available - including PAS, PKS, OpsManager, stemcells,
products and services.

Check out the [Downloading and Testing][downloading-and-testing] to get started.  


{% include ".internal_link_url.md" %}
{% include ".external_link_url.md" %}
