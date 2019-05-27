# Writing a Pipeline to Install Ops Manager
This how-to-guide shows you how to write a pipeline for installing a new Ops Manager - including configuring and creating the Ops Manager VM and BOSH Director. If you already have an Ops Manager VM, check out [Upgrading an Existing Ops Manager][upgrade-how-to]. 

{% include ".getting-started.md" %}

### Downloading Ops Manager

We're finally in a position to do work!

Let's switch out the test job
for one that downloads and installs Ops Manager.
We can do this by changing:

- the `name` of the job
- the `name` of the task
- the `file` of the task

Our first task within the job should be [`download-product`][download-product].
It has an additional required input;
we need the `config` file `download-product` uses to talk to Pivnet.

We'll write that file and make it available as a resource in a moment,
for now, we'll just `get` it
(and reference it in our params)
as if it's there.

It also has an additional output (the downloaded image).
We're just going to use it in a subsequent step,
so we don't have to `put` it anywhere.

Finally, while it's fine for `test` to run in parallel,
the install process shouldn't.
So, we'll add `serial: true` to the job, too.

```yaml hl_lines="2 3 15 16 17 18 19 20"
jobs:
- name: install-ops-manager
  serial: true
  plan:
    - get: platform-automation-image
      resource: platform-automation
      params:
        globs: ["*image*.tgz"]
        unpack: true
    - get: platform-automation-tasks
      resource: platform-automation
      params:
        globs: ["*tasks*.zip"]
        unpack: true
    - get: config
    - task: download-product
      image: platform-automation-image
      file: platform-automation-tasks/tasks/download-product.yml
      params:
        CONFIG_FILE: foundation/download-ops-manager.yml
```

If we try to `fly` this up to Concourse,
it will again complain about resources that don't exist.

So, let's make them.

The first new resource we need is the config file.
We'll push our git repo to a remote on Github
to make this (and later, other) configuration available to the pipelines.

Github has good [instructions][git-add-existing]
you can follow to create a new repository on Github.
You can skip over the part
about using `git init` to setup your repo,
since we [already did that](#but-first-git-init).

Once you've setup your remote
and used `git push` to send what you've got so far,
we can add a new directory to hold foundation-specific configuration.
(We'll use the name "foundation" for this directory,
but if your foundation has an actual name, use that instead.)

You will also need to add the repository URL
to `vars.yml` so we can reference it later,
when we declare the corresponding resource.

```yaml
pipeline-repo: git@github.com:username/platform-automation-pipelines
```

```bash
mkdir -p foundation
cd !$
```

`download-ops-manager.yml` holds creds for communicating with Pivnet,
and uniquely identifies an Ops Manager image to download.

An example `download-ops-manager.yml` is shown below.

If your foundation uses authentication other than basic auth,
please reference [Inputs and Outputs][env]
for more detail on UAA-based authentication.

Write an `download-ops-mananager.yml` for your Ops Manager.


```yaml tab="AWS"
---
pivnet-api-token: ((pivnet-token))
pivnet-file-glob: "ops-manager-aws*.yml"
pivnet-product-slug: ops-manager
product-version-regex: ^2\.5\.\d+$
```

```yaml tab="Azure"
---
pivnet-api-token: ((pivnet-token))
pivnet-file-glob: "ops-manager-azure*.yml"
pivnet-product-slug: ops-manager
product-version-regex: ^2\.5\.\d+$
```

```yaml tab="GCP"
---
pivnet-api-token: ((pivnet-token))
pivnet-file-glob: "ops-manager-gcp*.yml"
pivnet-product-slug: ops-manager
product-version-regex: ^2\.5\.\d+$
```

```yaml tab="OpenStack"
---
pivnet-api-token: ((pivnet-token))
pivnet-file-glob: "ops-manager-openstack*.raw"
pivnet-product-slug: ops-manager
product-version-regex: ^2\.5\.\d+$
```

```yaml tab="vSphere"
---
pivnet-api-token: ((pivnet-token))
pivnet-file-glob: "ops-manager-vsphere*.ova"
pivnet-product-slug: ops-manager
product-version-regex: ^2\.5\.\d+$
```

Add and commit the new file:

```bash
git add foundation/env.yml
git commit -m "Add environment file for foundation"
git push
```

Now that the env file we need is in our git remote,
we need to add a resource to tell Concourse how to get it as `env`.

Since this is (probably) a private repo,
we'll need to create a deploy key Concourse can use to access it.
Follow [Github's instructions][git-deploy-keys]
for creating a read-only deploy key.

Then, put the private key in Credhub so we can use it in our pipeline:

```bash
# note the starting space
 credhub set \
         --name /concourse/your-team-name/plat-auto-pipes-deploy-key \
         --type ssh \
         --private the/filepath/of/the/key-id_rsa \
         --public the/filepath/of/the/key-id_rsa.pub
```

Then, add this to the resources section of your pipeline file:

```yaml
- name: config
  type: git
  source:
    uri: ((pipeline-repo))
    private_key: ((plat-auto-pipes-deploy-key.private_key))
    branch: master
```

We'll need to put the pivnet token in Crehub:

```bash
# note the starting space throughout
 credhub set \
        -n /concourse/your-team-name/foundation/pivnet-token \
        -t value -v your-pivnet-token
```

{% include './.paths-and-pipeline-names.md' %}

In order to perform interpolation in one of our input files,
we'll need the [`credhub-interpolate` task][credhub-interpolate]
Earlier, we relied on Concourse's native integration with Credhub for interpolation.
That worked because we needed to use the variable
in the pipeline itself, not in one of our inputs.

We can add it to our job
after we've retrieved our `download-ops-manager.yml` input,
but before the `download-product` task:

```yaml hl_lines="16 17 18 19 20 21 22 23 24 25 26 27 28 34 35"
jobs:
- name: install-ops-manager
  serial: true
  plan:
    - get: platform-automation-image
      resource: platform-automation
      params:
        globs: ["*image*.tgz"]
        unpack: true
    - get: platform-automation-tasks
      resource: platform-automation
      params:
        globs: ["*tasks*.zip"]
        unpack: true
    - get: config
    - task: credhub-interpolate
      image: platform-automation-image
      file: platform-automation-tasks/tasks/credhub-interpolate.yml
      params:
        CREDHUB_CLIENT: ((credhub-client))
        CREDHUB_SECRET: ((credhub-secret))
        CREDHUB_SERVER: https://your-credhub.example.com
        PREFIX: /concourse/your-team-name/foundation
        INTERPOLATION_PATHS: foundation # contains download-ops-manager.yml
      input_mapping:
        files: env
      output_mapping:
        interpolated-files: interpolated-config
    - task: download-product        
      image: platform-automation-image
      file: platform-automation-tasks/tasks/download-product.yml
      params:
        CONFIG_FILE: foundation/download-ops-manager.yml
      input_mapping:
        config: interpolated-config
```

!!! info A bit on "output_mapping"
    <p>The `credhub-interpolate` task for this job
    maps the output from the task (`interpolated-files`)
    to `interpolated-config`.
    <p>This can be used by the next task in the job
    to more explicitly define the inputs/outputs of each task.
    It is also okay to leave the output as `interpolated-files`
    if it is appropriately referenced in the next task

Notice the [input mappings][concourse-input-mapping]
of the `credhub-interpolate` and `download-product` tasks.
This allows us to use the output of one task
as in input of another.

We now need to put our `credhub_client` and `credhub_secret` into Credhub,
so Concourse's native integration can retrieve them
and pass them as configuration to the `credhub-interpolate` task.

```bash
# note the starting space throughout
 credhub set \
        -n /concourse/your-team-name/credhub-client \
        -t value -v your-credhub-client
 credhub set \
        -n /concourse/your-team-name/credhub-secret \
        -t value -v your-credhub-secret
```

Now, the `credhub-interpolate` task
will interpolate our config input,
and pass it to `download-product` as `config`.

The job will download the product now.
This is a good commit point.

```bash
git add pipeline.yml
git commit -m 'download the Ops Manager image'
git push
```

### Creating Resources for Your Ops Manager

Before Platform Automation can create a VM for your Ops Manager installation,
there are a certain number of resources
required by the VM creation and the Ops Manager director installation processes.
These resources are created directly on the IaaS of your choice,
and read in as configuration for your Ops Manager.

There are two main ways of creating these resources,
and you should use whichever method is right for you and your setup.

**Terraform**:

There are open source terraforming scripts
we recommend for use, as they are maintained by the Pivotal organization.
These scripts are found in open source repos under the `pivotal-cf` org in GitHub.

- [terraforming-aws][terraforming-aws]
- [terraforming-azure][terraforming-azure]
- [terraforming-gcp][terraforming-gcp]
- [terraforming-openstack][terraforming-openstack]
- [terraforming-vsphere][terraforming-vsphere]

Each of these repos contain instructions in their respective `README`s
designed to get you started. Most of the manual keys that you need to fill out
will be in a [terraform.tfvars][terraform-vars] file
(for more specific instruction, please consult the `README`).

If there are specific aspects of the terraforming repos that do not work for you,
you can overwrite _some_ properties using an [override.tf][terraform-override] file.

**Manual Installation**:

Pivotal has extensive documentation to manually create the resources needed
if you are unable or do not wish to use Terraform.
As with the Terraform solution, however,
there are different docs depending on the IaaS
you are installing Ops Manager onto.

When going through the documentation required for your IaaS,
be sure to stop before deploying the Ops Manager image.
Platform Automation will do this for you.

- [aws][manual-aws]
- [azure][manual-azure]
- [gcp][manual-gcp]
- [openstack][manual-openstack]
- [vsphere][manual-vsphere]

_NOTE_: if you need to install an earlier version of Ops Manager,
select your desired version from the dropdown at the top of the page.


### Creating the Ops Manager VM

Now that we have an Ops Manager image and the resources required to deploy a VM,
let's add the new task to the `install-opsman` job.

```yaml hl_lines="36 37 38"
jobs:
- name: install-ops-manager
  serial: true
  plan:
    - get: platform-automation-image
      resource: platform-automation
      params:
        globs: ["*image*.tgz"]
        unpack: true
    - get: platform-automation-tasks
      resource: platform-automation
      params:
        globs: ["*tasks*.zip"]
        unpack: true
    - get: config
    - task: credhub-interpolate
      image: platform-automation-image
      file: platform-automation-tasks/tasks/credhub-interpolate.yml
      params:
        CREDHUB_CLIENT: ((credhub-client))
        CREDHUB_SECRET: ((credhub-secret))
        CREDHUB_SERVER: https://your-credhub.example.com
        PREFIX: /concourse/your-team-name/foundation
        INTERPOLATION_PATHS: foundation # contains download-ops-manager.yml
      input_mapping:
        files: env
      output_mapping:
        interpolated-files: interpolated-config
    - task: download-product        
      image: platform-automation-image
      file: platform-automation-tasks/tasks/download-product.yml
      params:
        CONFIG_FILE: foundation/download-ops-manager.yml
      input_mapping:
        config: interpolated-config
    - task: create-vm
      image: platform-automation-image
      file: platform-automation-tasks/tasks/create-vm.yml
```

If we try to `fly` this up to Concourse, it will again complain about resources that don't exist.

So, let's make them.

Looking over the list of inputs for `create-vm` we still need two required inputs:

1. `config`
1. `state`

The optional inputs are vars used with the config, so we'll get to those when we do `config`.

Let's start with the config file.
We'll write an [Ops Manager VM Configuration file][opsman-config]
to `foundation/opsman.yml`.

The properties available vary by IaaS, for example:

* IaaS credentials
* networking setup (IP address, subnet, security group, etc)
* ssh key
* datacenter/availability zone/region

``` yaml tab="AWS"
{% include './examples/howto/aws.yml' %}
```

``` yaml tab="Azure"
{% include './examples/howto/azure.yml' %}
```

``` yaml tab="GCP"
{% include './examples/howto/gcp.yml' %}
```

``` yaml tab="OpenStack"
{% include './examples/howto/openstack.yml' %}
```

``` yaml tab="vSphere"
{% include './examples/howto/vsphere.yml' %}
```


These examples all make assumptions
about the details of your soon-to-be Ops Manager's configuration.
See [the reference docs for this file][opsman-config]
for more details about your options and per-IaaS caveats.

Once you have your config file, commit and push it:

```bash
git add foundation/opsman.yml
git commit -m "Add opsman config"
git push
```

The `state` input is a placeholder
which will be filled in by the `create-vm` task output.
This will be used later to keep track of the vm so it can be upgraded,
which you can learn about in the [upgrade-how-to].

The `create-vm` task in the `install-opsman` will need to be updated to
use the `download-product` image,
Ops Manager configuration file,
and the placeholder state file.

```yaml hl_lines="39 40 41 42 43 44 45"
jobs:
- name: install-ops-manager
  serial: true
  plan:
    - get: platform-automation-image
      resource: platform-automation
      params:
        globs: ["*image*.tgz"]
        unpack: true
    - get: platform-automation-tasks
      resource: platform-automation
      params:
        globs: ["*tasks*.zip"]
        unpack: true
    - get: config
    - task: credhub-interpolate
      image: platform-automation-image
      file: platform-automation-tasks/tasks/credhub-interpolate.yml
      params:
        CREDHUB_CLIENT: ((credhub-client))
        CREDHUB_SECRET: ((credhub-secret))
        CREDHUB_SERVER: https://your-credhub.example.com
        PREFIX: /concourse/your-team-name/foundation
        INTERPOLATION_PATHS: foundation # contains download-ops-manager.yml
      input_mapping:
        files: env
      output_mapping:
        interpolated-files: interpolated-config
    - task: download-product        
      image: platform-automation-image
      file: platform-automation-tasks/tasks/download-product.yml
      params:
        CONFIG_FILE: foundation/download-ops-manager.yml
      input_mapping:
        config: interpolated-config
    - task: create-vm
      image: platform-automation-image
      file: platform-automation-tasks/tasks/create-vm.yml
      params:
        OPSMAN_CONFIG_FILE: foundation/opsman.yml
        STATE_FILE: foundation/state.yml
      input_mapping:
        config: interpolated-config
        state: config
        image: downloaded-product
```

Set the pipeline.

Before we run the job,
we should [`ensure`][ensure] that `state.yml` is always persisted
regardless of whether the `install-opsman` job failed or passed.
To do this, we can add the following section to the job:

```yaml hl_lines="46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65"
jobs:
- name: install-ops-manager
  serial: true
  plan:
    - get: platform-automation-image
      resource: platform-automation
      params:
        globs: ["*image*.tgz"]
        unpack: true
    - get: platform-automation-tasks
      resource: platform-automation
      params:
        globs: ["*tasks*.zip"]
        unpack: true
    - get: config
    - task: credhub-interpolate
      image: platform-automation-image
      file: platform-automation-tasks/tasks/credhub-interpolate.yml
      params:
        CREDHUB_CLIENT: ((credhub-client))
        CREDHUB_SECRET: ((credhub-secret))
        CREDHUB_SERVER: https://your-credhub.example.com
        PREFIX: /concourse/your-team-name/foundation
        INTERPOLATION_PATHS: foundation # contains download-ops-manager.yml
      input_mapping:
        files: env
      output_mapping:
        interpolated-files: interpolated-config
    - task: download-product        
      image: platform-automation-image
      file: platform-automation-tasks/tasks/download-product.yml
      params:
        CONFIG_FILE: foundation/download-ops-manager.yml
      input_mapping:
        config: interpolated-config
    - task: create-vm
      image: platform-automation-image
      file: platform-automation-tasks/tasks/create-vm.yml
      params:
        OPSMAN_CONFIG_FILE: foundation/opsman.yml
        STATE_FILE: foundation/state.yml
      input_mapping:
        config: interpolated-config
        state: config
        image: downloaded-product
      ensure:
        do:
          - task: make-commit
            image: platform-automation-image
            file: platform-automation-tasks/tasks/make-git-commit.yml
            input_mapping:
              repository: config
              file-source: generated-state
            output_mapping:
              repository-commit: config-commit
            params:
              FILE_SOURCE_PATH: state.yml
              FILE_DESTINATION_PATH: ((foundation))/state/state.yml
              GIT_AUTHOR_EMAIL: "pcf-pipeline-bot@example.com"
              GIT_AUTHOR_NAME: "Platform Automation Bot"
              COMMIT_MESSAGE: 'Update state file'
          - put: config
            params:
              repository: config-commit
              merge: true
```

Set the pipeline one final time,
run the job, and see it pass.

```bash
git add pipeline.yml
git commit -m "Install Ops Manager in CI"
git push
```

Your install pipeline is now complete.
You are now free to move on to the next steps of your automation journey.

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
