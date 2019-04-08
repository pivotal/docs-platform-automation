# How to: Upgrade an Existing Ops Manager

The following is a _How To Guide_ on setting up and using Platform Automation.
This guide assumes you already have a foundation that needs to be automated, 
or you are coming from a different form of automation (such as `pcf-pipelines`)

## Prerequisites

In addition to the prerequisites listed in [Downloading and Testing][downloading-and-testing],
the Platform Automation team recommends the following:

* Installed [Docker CLI][docker-cli]
    
    There are a couple one-off tasks that can be either saved in your pipeline, 
    or run once from the command line using our Docker image. The preference to 
    do either is your choice, but the How To Guide will be using the Docker CLI.
    
* Basic knowledge of [Git][git], and a [GitHub][github] account.

    Several tasks mutate state and configuration files
    that are best persisted in a remote version control system.
    For the purposes of this guide, we'll use GitHub.
    
* [Amazon S3][amazon-s3] or [Minio][minio]
    
    While any blobstore may be used, this _How To Guide_ will be 
    using an s3-compatible blobstore.
    
* A fully installed foundation (either PAS or PKS) with all relevant tiles similarly
  configured and installed
  
    !!! warning
        Upgrading Ops Manager _requires_ that your foundation have no pending apply-changes.
        The exported installation will not reflect any pending changes, and will not export 
        at all if the foundation has not fully installed at least the Ops Manager BOSH director.
        

## Goals and Overview

The goal of this How To Guide is to build up a portion of the [Reference Pipeline][reference-pipeline]
and the [Reference Resources Pipeline][reference-resources]
that is relevant for upgrading Ops Manager for an already existing foundation. This guide will go 
through the following steps:

1. Retrieving Ops Manager, PAS, Healthwatch, and Platform Automation from Pivnet and storing 
  in an s3 blobstore
1. How to interpolate the configs using credhub, and feeding these interpolated configs into 
   the concourse tasks
1. How to setup a sample github repo 
1. Setup recommended file structure
1. Create required files for Upgrade
1. Retrieve the existing config from Ops Manager using `docker run`
1. Retrieve the existing config from PAS and Healthwatch using `docker run`
1. Create a pipeline to upgrade Ops Manager
  
TODO: link the above to the headers below (after design review)

## Retrieving Resources from Pivnet

When creating a Concourse pipeline, we will expand the following base structure:
```yaml
resource_types:
resources:
jobs:
```

Concourse has many [Resource Types][concourse-resource-types] built in, but for the 
purpose of this reference pipeline, we will be utilizing the [Pivotal pivnet-resource][pivnet-resource]
to directly communicate with and download products from Pivnet.

To tell concourse that we will be using the Pivnet resource, we will have to include
the following in your `resource_types` section:
```yaml
{% include './examples/pipeline-snippets/resource-types/pivnet.yml' %}
```

After listing the "custom" resource type, we can then list the resources that our foundation
requires. For this guide, our foundation includes: Ops Manager, Pivotal Application Service (PAS),
and Healthwatch. The general automated workflow for fetching and storing resources is as follows:

TODO: link to the appropriate sections (after design review)

1. Setup your s3 with the appropriate credentials/buckets for your foundation
1. [Download product and stemcell](#download-product-and-products-stemcell) (using `download-product`) 
   and store in an s3 bucket
1. Download Platform Automation from Pivnet

The resources required to accomplish these tasks include:

* healthwatch-product s3 storage location
* healthwatch-stemcell s3 storage location
* ops-manager s3 storage location
* pas-product s3 storage location
* pas-stemcell s3 storage location
* platform-automation-docker-image s3 storage location
* platform-automation-tasks storage location

To reference the storage locations in Concourse, you are required to have the 

* access_key_id and secret_access_key for accessing the appropriate bucket
* the name of the bucket for storing the product(s)
* the region the bucket is located in
* a regex that describes the filename of the product being stored (to prevent the
  wrong product/version from being stored/accessed later) 

The following example assumes that all of your products live in the same s3 bucket, thus
their `regexp` are very specific to match the slug/version.

To retrieve the platform-automation product, there is no stemcell, and thus the download
process is much simpler than with Ops Manager products. Therefore, we can use the Pivnet
resource we defined earlier and pull from Pivnet directly. The product can be stored in s3
the same way that the other products can. We can add all of these resources to our pipeline
under the `resources` section:

``` yaml tab="Healthwatch"
{% include './examples/resources-pipeline/concourse-resources/healthwatch.yml' %}
```

``` yaml tab="PAS"
{% include './examples/resources-pipeline/concourse-resources/pas.yml' %}
```

``` yaml tab="Ops Manager"
{% include './examples/resources-pipeline/concourse-resources/opsman.yml' %}
```

``` yaml tab="Platform Automation"
{% include './examples/resources-pipeline/concourse-resources/platform-automation.yml' %}
```

### Parametrizing Secrets, and Using Credhub Interpolate 

This example pipeline will make heavy use of the [`credhub-interpolate`][credhub-interpolate]
task. For more information on how this works, and how to set it up and use it properly, 
please see the [Secrets Handling][secrets-handling] page. 

The [config file][download-product-config] used in the following section mixes secret and 
non-secret variables. When choosing which variables to keep in the config file, and which ones
to `((parametrize))`, you should consider whether public access to the variable would be a 
concern. If choosing to parametrize, you will need to first use 
[`credhub-interpolate`][credhub-interpolate] to substitute the Credhub values into the config 
for the next task to use. 

!!! info 
    Parametrized configurations that are interpolated by Credhub return a config file with the 
    formerly parametrized variables with their Credhub values. Concourse VMs are ephemeral, and
    these full config files are only available in the specific job, and will not be persisted.

An example of how to use this in the resources pipeline is shown below. We will be defining this
"task" external to jobs and resources, so that it can be used in multiple jobs while keeping the yaml
clean.
```yaml
{% include './examples/anchors/credhub-interpolate.yml' %}
```

When referencing the above "task" we will be calling it with the yaml below. This will expand the 
anchor `*credhub-interpolate` with the concourse-readable data we defined in `&credhub-interpolate` above.
```yaml
{% include './examples/anchors/subbing-credhub-interpolate.yml' %}
```


### Download Product and Product's Stemcell 

Before downloading a product,
you need a [config file][download-product-config]
for [download-product][download-product].

Commented out fields are entirely optional and should only be used if you have a need to do 
so. Explanations for each field are given below.

{% code_snippet 'examples', 'download-product-config-parametrized' %}

To fetch a product from Pivnet, concourse needs to know:
 
* what image it will run the task on (`platform-automation-image`)
* where the task file will come from (`platform-automation-tasks`) 
* what config file it will read from to get data about pivnet and the tile (this is 
  the `download-product-config` created above)
* how to map the output from the task to something you will use later
* where to put the output resources created in the task

These requirements gathered together and executed in a task could look like the snippet below.
The snippet involves downloading Healthwatch. However, Healthwatch can be easily replaced by
any other tile. The only pieces that would need to change are the task name (if being specific), 
the name of the stemcell (if mapping), the name of the `download-product-config`, and the `put`'s 
specified after the product and stemcell are downloaded. 

``` yaml tab="Healthwatch"
{% include './examples/resources-pipeline/download-product-task/healthwatch.yml' %}
```

``` yaml tab="PAS"
{% include './examples/resources-pipeline/download-product-task/pas.yml' %}
```

Concourse requires tasks to be within jobs.
For convenience,
and ease of explanation,
we have created a separate job for each product.
These tasks can easily be combined into a single job.
Benefits of doing this could include running `credhub-interpolate` only once,
(instead of once for each job).
One downside of structuring your pipeline with many tasks in a given job
is that you lose the ability to rerun just a particular section of the job that failed.
This means Concourse would run every task again
if the job was triggered a second time.

To make sure your blobstore always has the most recent version of a pivnet product, you can use the
built-in time resource, to tell the `fetch` jobs how often to run and attempt to download a new version
of the product and/or stemcell. To add this functionality to your pipeline, you must include the time
resource in your `resources` section:
```yaml
{% include './examples/pipeline-snippets/resources/daily-trigger.yml' %}
```

If included, this resource can be referenced in any appropriate job, and you can set the job to trigger
on that daily (or custom) interval.

Examples of the `fetch-{product}` job are shown below. The job includes the task we created above,
the daily time trigger, and the interpolate created in an 
[earlier step](#parametrizing-secrets-and-using-credhub-interpolate). These jobs should be included under the 
`jobs` header in your pipeline.

```yaml tab="Healthwatch"
{% include './examples/resources-pipeline/fetch-job/healthwatch.yml' %}
```

```yaml tab="PAS"
{% include './examples/resources-pipeline/fetch-job/pas.yml' %}
```

```yaml tab="Ops Manager"
{% include './examples/resources-pipeline/fetch-job/opsman.yml' %}
```

### Download Platform Automation from Pivnet

Downloading the Platform Automation toolset does not use `download-product`.
Using download-product for this would require the product have a dependency on itself.
Instead, we use the `pivnet-resource` we defined earlier.

The Platform Automation team recommends triggering `fetch-platform-automation`
whenever there is a new version available.
The resource definition for platform automation from above
is pinned to the major version.
Pinning to the major version but letting the minor and patch version increase
allows you to get security updates, bug fixes, and new (non-breaking) features.
Platform Automation uses [semantic versioning][semantic-versioning] to enable this.

To download the Platform Automation tasks and the Docker image, and put it into your s3 blobstore, add
the following `job`:
```yaml
{% include './examples/resources-pipeline/fetch-job/platform-automation.yml' %}
``` 

### A Complete Resources Pipeline

Now that we have built up the resources pipeline, you can find this full example on the 
[Reference Pipeline][reference-resources] page. This also includes an example of fetching a 
Windows tile, but if you understand the concepts above, you can use the Windows tile, the mySQL tile, 
or any other tile you desire for your foundation.

## Sample Github repository and file structure

Now let's dive into using version control
to manage state in pipelines built with Platform Automation.
We'll set up a git repository on Github,
and the recommended directory structure for the repo. 

### Git and Github

Git is a commonly used version control tool.
It can be used to track code changes made to files within a repository (or "repo").
Changes can then be "pushed" to or "pulled" from remote copies of that repository.

Github is a system that provides git remotes.
Using a remote will enable the pipeline we are creating
to access and update the state and configuration files.

To learn more about git and github,
you can [read this short git handbook][github-git-handbook].

To create our Github repo:

1. Create a new repository
1. Using the "Example: Start a new repository and publish it to GitHub"
   section of the [Git handbook][github-git-handbook] (about 3/4 down the page), 
   create a repo, add a file, and push it to Github.

### Creating Repo Directory Structure

You now have both a local git repo and a remote on Github.
The recommended structure for a config repo is:

```tree
├── foundation
│   ├── config
│   ├── env
│   ├── state
│   └── vars
```

These directories are needed for this guide.

<table>
    <tr>
        <td>config</td>
        <td>
            Holds config files for the products installed on your foundation.
            If using Credhub and/or vars files,
            these config files should have your <code>((parametrized))</code> values present in them
        </td>
    </tr>
    <tr>
        <td>env</td>
        <td>
            Holds <code>env.yml</code>,
            the environment file used by tasks that interact with Ops Manager.
        </td>
    </tr>
    <tr>
        <td>vars</td>
        <td>
          Holds product-specific vars files.
        </td>
    </tr>
    <tr>
        <td>state</td>
        <td>
            Holds <code>state.yml</code>,
            which contains the VM ID for the Ops Manager VM.
        </td>
    </tr>
</table> 

## Creating the Required Files

Several files are required for upgrading an Ops Manager VM.
They are used to capture the current state of the Ops Manager VM.

### Ops Manager VM State

We'll need to capture the current Ops Manager VM identifier,
so we know what VM we are upgrading.
To create a `state.yml` from your existing foundation,
use the following as a template, based on your IaaS:

``` yaml tab="AWS"
{% include './examples/state/aws.yml' %}
```

``` yaml tab="Azure"
{% include './examples/state/azure.yml' %}
```

``` yaml tab="GCP"
{% include './examples/state/gcp.yml' %}
```

``` yaml tab="OpenStack"
{% include './examples/state/openstack.yml' %}
```

``` yaml tab="vSphere"
{% include './examples/state/vsphere.yml' %}
```

### Ops Manager VM Configuration

`opsman.yml` is the configuration file for `p-automator`,
which calls out to specific IaaS CLIs in order to create/update/delete a VM.

The properties contained in `opsman.yml` differ based on your IaaS:

``` yaml tab="AWS"
{% include './examples/opsman-config/aws.yml' %}
```

``` yaml tab="Azure"
{% include './examples/opsman-config/azure.yml' %}
```

``` yaml tab="GCP"
{% include './examples/opsman-config/gcp.yml' %}
```

``` yaml tab="OpenStack"
{% include './examples/opsman-config/openstack.yml' %}
```

``` yaml tab="vSphere"
{% include './examples/opsman-config/vsphere.yml' %}
```

### Ops Manager Environment File

`env.yml` holds authentication and target information
for a particular Ops Manager.
This file is required by `upgrade-opsman`
because after the VM is recreated,
the task will import the provided installation.zip
to Ops Manager to finish the process.

If your foundation uses authentication other than basic auth,
please reference [Inputs and Outputs][env] for more detail on UAA-based authentication.

An example `env.yml` is shown below.
As mentioned in the comment,
`decryption-passphrase` is required for `import-installation`,
and therefore required for `upgrade-opsman`.

{% code_snippet 'examples', 'env' %}

### Vars files

If you are using files to store vars be rendered into your configuration templates,
these files should be  in your git repo under the `vars` directory.
For more information on vars files, see [Secrets Handling][secrets-handling].

### Valid exported Ops Manager installation

`upgrade-opsman` will not allow you to execute the task unless the installation 
provided to the task is a installation provided by Ops Manager itself. In the UI, this is located 
on the [Settings Page][opsman-settings-page] of Ops Manager.

Platform Automation _**strongly recommends**_ automatically exporting and persisting the Ops 
Manager installation on a regular basis. In order to do so, you can set your pipeline to run the 
[`export-installation`][export-installation] task on a daily trigger. This should be persisted into 
S3 or a blobstore of your choice.

You can start your pipeline by first creating this `export-installation` task and persisting it in an S3
bucket.

{% include "./.export_installation_note.md" %}

Requirements for this task include:

* the Platform Automation image
* the Platform Automation tasks
* a configuration path for your env file
* interpolation of the env file with credhub
* a resource to store the exported installation into

Starting our concourse pipeline, we need the following resources:
```yaml
{% include './examples/pipeline-snippets/resources/common.yml' %}

{% include './examples/pipeline-snippets/resources/installation.yml' %}
```

In our `jobs` section, we need a job that will trigger daily to pull down the Ops Manager
installation and store it in S3. This looks like the following:

```yaml
{% include './examples/pipeline-snippets/jobs/export-installation.yml' %}
```

Once this resource is persisted, we can safely run `upgrade-opsman`, knowing that we can 
never truly lose our foundation. This is also important in case something happens to the VM
externally (whether accidentally deleted, or a similar disaster occurs). If something _does_
happen to the original Ops Manager VM, this installation can be imported by any newly created Ops Manager
VM.

{% include "./.export_installation_note.md" %}

## Retrieving Existing Ops Manager Director Configuration
If you would like to automate the configuration of your Ops Manager, you first need to externalize
the director configuration. Using Platform Automation, this is done using Docker or by adding a job to
the pipeline.

**Docker**

To get the currently configured Ops Manager configuration, we have to:

1. Import the image
```bash
{% include './examples/docker/import-image.sh' %}
```
Where `${PLATFORM_AUTOMATION_IMAGE_TGZ}` is the image file downloaded from Pivnet.

2. Then, you can use `docker run` to pass it arbitrary commands.
Here, we're running the `om` CLI to see what commands are available:
```bash
{% include './examples/docker/om-help.sh' %}
```

Note:  that this will have access read and write files in your current working directory.
If you need to mount other directories as well, you can add additional `-v` arguments.

The command we will use to extract the current director configuration is called 
[`staged-director-config`][staged-director-config]. This is an `om` command that calls
the Ops Manager API to pull down the currently configured director configuration. To run this
using Docker, you will need the env file created above as `${ENV_FILE}`: 

```bash
{% include './examples/docker/staged-director-config.sh' %}
```

`--include-placeholders` is an optional flag, but highly recommended if you want a full
configuration for your Ops Manager. This flag will replace any fields marked as "secret" 
in your Ops Manager config with ((parametrized)) variables. If you would prefer to not
work with ((parametrized)) variables, you can substitute `--include-placeholders` with
`--include-credentials`.
 
!!! warning
    `--include-credentials` WILL expose passwords and 
    secrets in _plain text_. Therefore, `--include-placeholders` is recommended, but not required.

**Pipeline**

To add [`staged-director-config`] to your pipeline, you will need the following resources:

* the Platform Automation image
* the Platform Automation tasks
* a configuration path for your env file
* a resource to store the exported configuration into

Starting our Concourse pipeline, we need the following `resources`:
```yaml
{% include './examples/pipeline-snippets/resources/common.yml' %}
```

In our `jobs` section, we need a job that will interpolate the env file, pull down the 
Ops Manager director config, and store the director config in the configuration directory
(this can be the same resource as where the env is located, but will be stored in the `config`
instead of the `env` directory). In order to persist the director config in your git repo,
we first need to make a commit, detailing the change we made, and where in your git repo the 
change happened. A way to do this is shown below:

```yaml
{% include './examples/pipeline-snippets/jobs/staged-director-config.yml' %}
```

## Retrieving Existing Product Configurations

If you would like to automate the configuration of your product tiles, you first need to externalize
each product's configuration. Using Platform Automation, this is done using Docker or by adding a job to
the pipeline.

**Docker**

As an example, we are going to start with the PAS tile.
To get the currently configured PAS configuration, we have to:

1. Import the image
```bash
{% include './examples/docker/import-image.sh' %}
```
Where `${PLATFORM_AUTOMATION_IMAGE_TGZ}` is the image file downloaded from Pivnet.

2. Then, you can use `docker run` to pass it arbitrary commands.
Here, we're running the `om` CLI to see what commands are available:
```bash
{% include './examples/docker/om-help.sh' %}
```

Note:  that this will have access read and write files in your current working directory.
If you need to mount other directories as well, you can add additional `-v` arguments.

The command we will use to extract the current director configuration is called 
[`staged-config`][staged-config]. This is an `om` command that calls
the Ops Manager API to pull down the currently configured product configuration given
a product slug. To run this using Docker, you will need the env file created above as `${ENV_FILE}`.
The product slug for the PAS tile, within Ops Manager, is `cf`. To find the slug of your
product, you can run the following docker command:

```bash
{% include './examples/docker/staged-products.sh' %}
```

This will give you a table like the following:

```
+---------------+-----------------+
|     NAME      |     VERSION     |
+---------------+-----------------+
| cf            | 2.x.x           |
| p-healthwatch | 1.x.x-build.x   |
| p-bosh        | 2.x.x-build.x   |
+---------------+-----------------+
```

The values in the `NAME` column are the slugs of each product you have deployed. For this
_How to Guide_, we only have PAS and Healthwatch. 

!!! info 
    p-bosh is the product slug of Ops Manager. However, `staged-config` _**cannot**_ 
    be used to extract the director config. To do so, you must use `staged-director-config`


With the appropriate product `${SLUG}`, we can run the following docker command to pull down
the configuration of the chosen tile:
```bash
{% include './examples/docker/staged-config.sh' %}
```

`--include-placeholders` is an optional flag, but highly recommended if you want a full
configuration for your tile. This flag will replace any fields marked as "secret" 
by the product in the config with ((parametrized)) variables. If you would prefer to not
work with ((parametrized)) variables, you can substitute `--include-placeholders` with
`--include-credentials`.
 
!!! warning
    `--include-credentials` WILL expose passwords and 
    secrets in _plain text_. Therefore, `--include-placeholders` is recommended, but not required.

**Pipeline**

To add [`staged-config`] to your pipeline, you will need the following resources:

* the Platform Automation image
* the Platform Automation tasks
* a configuration path for your env file
* a resource to store the exported configuration into

Starting our Concourse pipeline, we need the following resources:
```yaml
{% include './examples/pipeline-snippets/resources/common.yml' %}
```

In our `jobs` section, we need a job that will interpolate the env file, pull down the 
product config, and store the director config in the configuration directory
(this can be the same resource as where the env is located, but will be stored in the `config`
instead of the `env` directory). In order to persist the product config in your git repo,
we first need to make a commit, detailing the change we made, and where in your git repo the 
change happened. A way to do this is shown below:

```yaml
{% include './examples/pipeline-snippets/jobs/staged-config.yml' %}
```

To retrieve the configuration for Healthwatch, we can simply duplicate the steps used for PAS. The `${SLUG}` 
for Healthwatch, as we retrieved from `staged-products`, is `p-healthwatch`

## Creating a Pipeline to Upgrade Ops Manager

With the director configuration, product configurations, resources gathered, and config files created, 
we can finally begin to create a pipeline that will automatically update your Ops Manager. 

At this point, your file tree should now look something like what is shown below. The following tree 
structure assumes that you are using a mix of vars files and credhub for each of the products used, 
for the Ops Manager director, and for the `upgrade-opsman` config file.

```
├── foundation
│   ├── config
│   │   ├── cf.yml
│   │   ├── director.yml
│   │   ├── healthwatch.yml
│   │   └── opsman.yml
│   ├── env
│   │   └── env.yml
│   ├── state
│   │   └── state.yml
│   └── vars
│       ├── cf-vars.yml
│       ├── director-vars.yml
│       ├── healthwatch-vars.yml
│       └── opsman-vars.yml
``` 

Let's review the resources that are required by Concourse for upgrading Ops Manager:
```yaml
resources:
{% include './examples/pipeline-snippets/resources/common.yml' %}

{% include './examples/pipeline-snippets/resources/installation.yml' %}

{% include './examples/pipeline-snippets/resources/opsman-image.yml' %}

# for exporting installation daily
{% include './examples/pipeline-snippets/resources/daily-trigger.yml' %}
```

Before we write the jobs portion of the pipeline, let's take a look at the tasks we should run
in order to function smoothly:

**a passing export installation**

In order for this job to run, a passing `export-installation` job must have been completed.
Again, by exporting the Ops Manager installation, we can ensure that we have a backup in-case of some
error. With a backed up installation, `upgrade-opsman` can be run over-and-over regardless of which stage
the task failed during. This is also important in case something happens to the VM externally (whether accidentally 
deleted, or a similar disaster occurs). If something _does_ happen to the original Ops Manager VM, this 
installation can be imported by any newly created Ops Manager VM. Please refer to 
[the Valid exported Ops Manager installation](#valid-exported-ops-manager-installation) 
section for details on this job. 

{% include "./.export_installation_note.md" %}

**interpolated env and config**

This job uses a mix of secret and non-secret variables that are interpolated from both Credhub and
vars files. This can be seen in both the `interpolate-config-creds` and `interpolate-env-creds` tasks.
These tasks return the `interpolated-config` and `interpolated-env` files that are further used by
the `upgrade-opsman` task. For further information on how this works and how you can set it up, see the 
[Parameterizing Secrets](#parametrizing-secrets-and-using-credhub-interpolate) section of this guide
and the [Secrets Handling][secrets-handling] page.

**ensure commit**

The `ensure` portion of this pipeline is used to ensure that the state file is committed to the repository,
whether upgrading succeeded or failed. This way, the repository always has the most up to date `state.yml` file
that reflects the current condition of Ops Manager. This is important so that subsequent runs of this task
or other tasks don't attempt to target a Ops Manager VM that is deleted or in a bad state.

!!! info
    When attempting to trouble-shoot the `upgrade-opsman` task, it may be necessary to manually remove
    the `vm_id` from your `state.yml` file. If the Ops Manager VM is in an unresponsive state or the 
    `state.yml` file does not reflect the most up to date VM information, (for example, if 
    the `ensure` fails for some reason) manually removing the `vm_id` will allow the upgrade task to 
    start in a fresh state and create the VM during the next run. 

**upgrade ops man task**

The `upgrade-opsman` task uses all the inputs provided, including the interpolated files, the 
Ops Manager image, the `state.yml` file, the `env.yml` file, and the `opsman.yml` file,
to run. Upon completion, Ops Manager will be upgraded. The following flowchart gives a high level overview
of how the task makes decisions for an upgrade:

{% include "./upgrade-flowchart.mmd" %}

On successive invocations of the task, it may offer different behaviour than the previous run.
This aids in recovering from failures (ie: from an IAAS) that occur. For examples on common errors and 
troubleshooting, see the [Troubleshooting](#troubleshooting) section.

**apply director changes task**

Finally, using the interpolated environment file, the `apply-director-changes` task will apply any remaining upgrade
changes to Ops Manager. Upon completion of this task, upgrading Ops Manager is now complete. 

By placing all of these tasks into a pipeline, you can get something like the following:
```yaml
jobs:
{% include './examples/pipeline-snippets/jobs/export-installation.yml' %}

{% include './examples/pipeline-snippets/jobs/upgrade-opsman.yml' %}
```

With your pipeline completed, you are now ready to trigger `export-installation`, and get started!

## Troubleshooting
When you are upgrading your Ops Manager you may get version check or IaaS CLI errors. For information about troubleshooting these errors, see [`Version Check Errors`][version-check-errors] and [`IaaS CLI Errors`][iaas-cli-errors] below.

### Version Check Errors
1) <b>Downgrading is not supported by Ops Manager</b> (Manual Intervention Required)

* Ops Manager does not support downgrading to a lower version.
* SOLUTION: Try the upgrade again with a newer version of Ops Manager.

2) <b>Could not authenticate with Ops Manager</b> (Manual Intervention Required)

* Credentials provided in the auth file do not match the credentials of an already deployed Ops Manager.
* SOLUTION: To change the credentials when upgrading an Ops Manager, you must update the password in your
Account Settings. Then, you will need to update the following two files with the changes:
  [`auth.yml`][auth-file]
  [`env.yml`][generating-env-file]

3) <b>The Ops Manager API is inaccessible</b> (Recoverable)

* The task could not communicate with Ops Manager.
* SOLUTION: Rerun the [`upgrade-opsman`][upgrade-opsman] task. The task will assume that the Ops Manager VM is not
created, and will run the [`create-vm`][create-vm] and
[`import-installation`][import-installation] tasks.

### IAAS CLI Errors

1) When the CLI for a supported IAAS fails for any reason (i.e., bad network, outage, etc) we treat this as
an IAAS CLI error. The following tasks can return an error from the IAAS's CLI: [`delete-vm`][delete-vm], [`create-vm`][create-vm]

* SOLUTION: The specific error will be returned as output, but <i><b>most errors can simply be fixed by
re-running the `upgrade-opsman` task.</b></i>


{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
