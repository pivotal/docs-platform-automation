# Overview

Platform Automation Toolkit provides building blocks
to create repeatable and reusable automated pipeline(s)
for upgrading and installing foundations.
We also provide instructions on using these building blocks in various workflows.
In this introduction, we'll provide a high-level overview of Platform Automation Toolkit.
To dive-deeper, check out the references section.

See the [Getting Started](./getting-started.md) section for instructions
on how to start using Platform Automation Toolkit.

## About Platform Automation Toolkit

* Uses the [GitHub om repo](https://github.com/pivotal-cf/om),
  (and by extension, the Tanzu Operations Manager API)
  to enable command-line interaction with Tanzu Operations Manager
  ([Understanding the Tanzu Operations Manager Interface](https://docs.vmware.com/en/VMware-Tanzu-Operations-Manager/3.0/vmware-tanzu-ops-manager/pcf-interface.html))

* Includes a documented reference pipeline
  showing one possible configuration to use tasks.
  When automating your platform,
  there are some manual steps you'll need to take to optimize for automation.
  We will call these steps out so that these are clear to you.

* Comes bundled with Concourse [tasks](https://concourse-ci.org/tasks.html)
  that demonstrate how to use these tasks
  in a containerized Continuous Integration (CI) system.
  Platform Automation Toolkit tasks are:

    * Legible: They use
      human-readable YAML config files which can be edited and managed

    * Modular: Each task has defined inputs and outputs
      that perform granular actions

    * Built for Automation: Tasks are idempotent,
      so re-running them in a CI won't break builds

    * Not Comprehensive: Workflows that use Platform Automation Toolkit
      may also contain `om` commands, custom tasks,
      and even interactions with the Tanzu Operations Manager user interface.
      Platform Automation Toolkit is a set of tools to use alongside other tools,
      rather than a comprehensive solution.

* A documented and supported deployment of Concourse CI to use with Platform Automation Toolkit.
  The [Concourse for Platform Automation docs](https://docs.vmware.com/en/Concourse-for-VMware-Tanzu/7.0/vmware-tanzu-concourse/GUID-installation-install-platform-automation.html) provide a step-by-step tutorial for how to get started.
  This approach to deploying Concourse uses the BOSH Director deployed by Tanzu Operations Manager to deploy and maintain Concourse, CredHub, and UAA.

The [Task Reference](./tasks.md) topic discusses these example tasks further.

<p class="note">
<span class="note__title">Note</span>
Platform Automation Toolkit takes a different approach than PCF Pipelines.
For instance, Platform Automation Toolkit allows you
to perform installs and upgrades in the same pipeline.
We recommend trying out Platform Automation Toolkit
to get a sense of the features and how they differ
to understand the best transition method for your environment and needs.</p>

## Platform Automation Toolkit and Upgrading Tanzu Operations Manager

Successful platform engineering teams know that a platform team
that's always up to date is critical for their business.
If they don’t stay up to date,
they miss out on the latest platform features and the services that VMware delivers,
which means their development teams miss out too.
By not keeping up to date,
platforms could encounter security risks or even application failures.

VMware offers regular updates for Tanzu Operations Manager and the products it installs,
which ensures our customers have access to the latest security patches and new features.
For example, VMware releases security patches every six days on average.

So how can a platform engineering team simplify the platform upgrade process?

### <a id=""></a> Small and Continuous Upgrades

Adopting the practice of small and constant platform updates
is one of the best ways to simplify the platform upgrade process.
This behavior can significantly reduce risk,
increase stability with faster troubleshooting,
and overall reduce the effort of upgrading.
This also creates a culture of continuous iteration
and improves feedback loops with the platform teams and the developers,
building trust across the organization.
A good place to start is to consume every patch.

How do we do this?

### <a id=""></a> Small and Continuous Upgrades With Platform Automation Toolkit

With Platform Automation Toolkit,
platform teams have the tools to create an automated perpetual upgrade machine,
which can continuously take the latest updates when new software is available -
including Tanzu Application Service, VMware Tanzu PKS, Tanzu Operations Manager, stemcells, products, and services.
In addition, Platform Automation Toolkit allows you to:

* manage multiple foundations and reduce configuration drift
  by tracking changes through source control with
  externalized configuration

* create pipelines that handle installs and upgrades to streamline workflows.

## Platform Automation Toolkit and Tanzu Operations Manager

The following table compares how Tanzu Operations Manager
and Platform Automation Toolkit might run a typical sequence of Tanzu Operations Manager operations:

<table>
  <thead><tr>
    <th></th>
    <th>Tanzu Operations Manager</th>
    <th>Platform Automation Toolkit</th>
  </tr></thead>
  <tbody><tr>
    <th>When to Use</th>
    <th>First install and minor upgrades</th>
    <th>Config changes and patch upgrades</th>
  </tr><tr>
    <th>1. Create Tanzu Operations Manager VM</th>
    <td>Manually prepare IaaS and create Tanzu Operations Manager VM</td>
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
    <td>Manually export existing Tanzu Operations Manager settings, power off the VM, then create a new, updated
    Tanzu Operations Manager VM</td>
    <td><code>export-installation</code> then <code>upgrade-opsman</code></td>
  </tr></tbody>
</table>

[//]: # ({% include ".internal_link_url.md" %})
[//]: # ({% include ".external_link_url.md" %})
