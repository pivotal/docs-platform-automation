# Writing a Pipeline to Install Ops Manager
This how-to-guide shows you how to write a pipeline for installing a new Ops Manager - 
including configuring and creating the Ops Manager VM and BOSH Director. 
If you already have an Ops Manager VM, check out [Upgrading an Existing Ops Manager][upgrade-how-to]. 

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
we need the `config` file `download-product` uses to talk to Tanzu Network.

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
        CONFIG_FILE: download-ops-manager.yml
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

Go ahead and setup your remote
and use `git push` to make what we have available.
We will use this repository to hold our single foundation specific configuration.
We are using the ["Single Repository for Each Foundation"][single-foundation-pattern]
pattern to structure our configurations.

You will also need to add the repository URL
to Credhub so we can reference it
later when we declare the corresponding resource.

```bash
# note the starting space throughout
 credhub set \
        -n /concourse/your_team_name/foundation/pipeline-repo \
        -t value -v git@github.com:username/your-repo-name
```

`download-ops-manager.yml` holds creds for communicating with Tanzu Network,
and uniquely identifies an Ops Manager image to download.

An example `download-ops-manager.yml` is shown below.

Create a `download-ops-manager.yml` for the IaaS you are using.

{% include ".opsman-config.md" %}

Add and commit the new file:

```bash
git add download-ops-manager.yml
git commit -m "Add download-ops-manager file for foundation"
git push
```

Now that the download-ops-manager file we need is in git,
we need to add a resource to tell Concourse how to get it as `config`.

Since this is (probably) a private repo,
we'll need to create a deploy key Concourse can use to access it.
Follow [Github's instructions][git-deploy-keys]
for creating a read-only deploy key.

Then, put the private key in Credhub so we can use it in our pipeline:

```bash
# note the space at the beginning of the next line
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

We'll need to put the Tanzu Network token in Credhub:

```bash
# note the starting space throughout
 credhub set \
    -n /concourse/your_team_name/foundation/pivnet_token \
    -t value -v your-pivnet-token
```

{% include './.paths-and-pipeline-names.md' %}

In order to perform interpolation in one of our input files,
we'll need the [`prepare-tasks-with-secrets` task][prepare-tasks-with-secrets]
Earlier, we relied on Concourse's native integration with Credhub for interpolation.
That worked because we needed to use the variable
in the pipeline itself, not in one of our inputs.

We can add it to our job
after we've retrieved our `download-ops-manager.yml` input,
but before the `download-product` task:

```yaml hl_lines="16 17 18 19 20 21 22 23"
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
    - task: prepare-tasks-with-secrets
      file: platform-automation-tasks/tasks/prepare-tasks-with-secrets.yml
      input_mapping:
        tasks: platform-automation-tasks
      output_mapping:
        tasks: platform-automation-tasks
      params:
        CONFIG_PATHS: config
    - task: download-product        
      image: platform-automation-image
      file: platform-automation-tasks/tasks/download-product.yml
      params:
        CONFIG_FILE: download-ops-manager.yml
```

Notice the [input mappings][concourse-input-mapping]
of the `prepare-tasks-with-secrets` task.
This allows us to use the output of one task
as in input of another.

Now, the `prepare-tasks-with-secrets` task
will find required credentials in the config files,
and modify the tasks,
so they will pull values from Concourse's integration of Credhub.

The job will download the product now.
This is a good commit point.

```bash
git add pipeline.yml
git commit -m 'download the Ops Manager image'
git push
```

### Creating Resources for Your Ops Manager

Before Platform Automation Toolkit can create a VM for your Ops Manager installation,
there are certain resources required by the VM creation and Ops Manager director installation processes.
These resources are created directly on the IaaS of your choice,
and read in as configuration for your Ops Manager.

There are two main ways of creating these resources,
and you should use whichever method is right for you and your setup.

**Terraform**:

These are open source terraforming files
we recommend for use, as they are maintained by VMware.
These files are found in the open source [`paving`][paving] repo on GitHub.

This is the recommended way to get these resources set up
as the output can directly be used in subsequent steps as property configuration.

The `paving` repo provides instructions for use in the `README`.
Any manual variables that you need to fill out
will be in a [terraform.tfvars][terraform-vars] file
in the folder for the IaaS you are using
(for more specific instruction, please consult the `README` for that IaaS).

If there are specific aspects of the `paving` repo that does not work for you,
you can override _some_ properties using an [override.tf][terraform-override] file.

Follow these steps to use the `paving` repository:

1. Clone the repo on the command line:

    ```bash
    cd ../
    git clone https://github.com/pivotal/paving.git
    ```

1. In the checked out repository there are directories for each IaaS.
   Copy the terraform templates for the infrastructure of your choice
   to a new directory outside of the paving repo, so you can modify it:

    ```bash
    # cp -Ra paving/${IAAS} paving-${IAAS}
    mkdir paving-${IAAS}
    cp -a paving/$IAAS/. paving-$IAAS
    cd paving-${IAAS} 
    ```

    `IAAS` must be set to match one of the infrastructure directories
    at the top level of the `paving` repo - for example,
    `aws`, `azure`, `gcp`, or `nsxt`.

1. Within the new directory, the `terraform.tfvars.example` file
   shows what values are required for that IaaS.
   Remove the `.example` from the filename,
   and replace the examples with real values.

1. Initialize Terraform which will download the required IaaS providers.

    ```bash
    terraform init
    ```

1. Run `terraform refresh` to update the state with what currently exists on the IaaS.

    ```bash
    terraform refresh \
      -var-file=terraform.tfvars
    ```

1. Next, you can run `terraform plan`
   to see what changes will be made to the infrastructure on the IaaS.

    ```bash
    terraform plan \
      -out=terraform.tfplan \
      -var-file=terraform.tfvars
    ```

1. Finally, you can run `terraform apply`
   to create the required infrastructure on the IaaS.

    ```bash
    terraform apply \
      -parallelism=5 \
      terraform.tfplan 
    ```

1. Save off the output from `terraform output stable_config`
   into a `vars.yml` file in `your-repo-name` for future use:

    ```bash
    terraform output stable_config > ../your-repo-name/vars.yml
    ```

1. Return to your working directory for the post-terraform steps:

    ```bash
    cd ../your-repo-name
    ```

1. Commit and push the updated `vars.yml` file:

    ```bash
    git add vars.yml
    git commit -m "Update vars.yml with terraform output"
    git push
    ```

**Manual Installation**:

VMware has extensive documentation to manually create the resources needed
if you are unable or do not wish to use Terraform.
As with the Terraform solution, however,
there are different docs depending on the IaaS
you are installing Ops Manager onto.

When going through the documentation required for your IaaS,
be sure to stop before deploying the Ops Manager image.
Platform Automation Toolkit will do this for you.

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

```yaml hl_lines="29 30 31"
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
    - task: prepare-tasks-with-secrets
      file: platform-automation-tasks/tasks/prepare-tasks-with-secrets.yml
      input_mapping:
        tasks: platform-automation-tasks
      output_mapping:
        tasks: platform-automation-tasks
      params:
        CONFIG_PATHS: config
    - task: download-product        
      image: platform-automation-image
      file: platform-automation-tasks/tasks/download-product.yml
      params:
        CONFIG_FILE: download-ops-manager.yml
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
We'll write an Ops Manager VM Configuration file to `opsman.yml`.

The properties available vary by IaaS, for example:

* IaaS credentials
* networking setup (IP address, subnet, security group, etc)
* ssh key
* datacenter/availability zone/region

#### Terraform Outputs

If you used the `paving` repository from the [Creating Resources for Your Ops Manager][creating-resources-for-your-ops-manager] section,
the following steps will result in a filled out `opsman.yml`.

1. Ops Manager needs to be deployed with IaaS specific configuration.
   Platform Automation Toolkit provides a configuration file format that looks like this:

    Copy and paste the YAML below for your IaaS
    and save as `opsman.yml`.

    ```yaml tab="AWS"
    --8<-- "external/paving/ci/configuration/aws/ops-manager.yml"
    ```

    ```yaml tab="Azure"
    --8<-- "external/paving/ci/configuration/azure/ops-manager.yml"
    ```

    ```yaml tab="GCP"
    --8<-- "external/paving/ci/configuration/gcp/ops-manager.yml"
    ```
   
    ```yaml tab="vSphere+NSXT"
    --8<-- "external/paving/ci/configuration/nsxt/ops-manager.yml"
    ```

     Where:
     {: .tightSpacing }

     * The `((parameters))` in these examples map to outputs from the `terraform-outputs.yml`,
       which can be provided via vars file for YAML interpolation in a subsequent step.

    !!! info "`opsman.yml` for an unlisted IaaS"
        For a supported IaaS not listed above,
        reference the [Platform Automation Toolkit docs](https://docs.pivotal.io/platform-automation/v4.3/inputs-outputs.html#ops-manager-config).

#### Manual Configuration

If you created your infrastructure manually
or would like additional configuration options,
these are the acceptable keys for the `opsman.yml` file for each IaaS.

{% code_snippet 'examples', 'aws-configuration', 'AWS' %}
{% code_snippet 'examples', 'azure-configuration', 'Azure' %}
{% code_snippet 'examples', 'gcp-configuration', 'GCP' %}
{% code_snippet 'examples', 'openstack-configuration', 'Openstack' %}
{% code_snippet 'examples', 'vsphere-configuration', 'vSphere' %}

#### Using the Ops Manager Config file

Once you have your config file, commit and push it:

```bash
git add opsman.yml
git commit -m "Add opsman config"
git push
```

The `state` input is a placeholder
which will be filled in by the `create-vm` task output.
This will be used later to keep track of the VM so it can be upgraded,
which you can learn about in the [upgrade-how-to][upgrade-how-to].

Add the following to your `resources` section of your `pipeline.yml`
```yaml
- name: vars
  type: git
  source:
    uri: ((pipeline-repo))
    private_key: ((plat-auto-pipes-deploy-key.private_key))
    branch: master
```

This resource definition will allow `create-vm`
to use the variables from `vars.yml`
in the `opsman.yml` file.

The `create-vm` task in the `install-opsman` will need to be updated to
use the `download-product` image,
Ops Manager configuration file,
and the placeholder state file.

```yaml hl_lines="33 34 35"
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
    - get: vars
    - task: prepare-tasks-with-secrets
      file: platform-automation-tasks/tasks/prepare-tasks-with-secrets.yml
      input_mapping:
        tasks: platform-automation-tasks
      output_mapping:
        tasks: platform-automation-tasks
      params:
        CONFIG_PATHS: config
    - task: download-product        
      image: platform-automation-image
      file: platform-automation-tasks/tasks/download-product.yml
      params:
        CONFIG_FILE: download-ops-manager.yml
    - task: create-vm
      image: platform-automation-image
      file: platform-automation-tasks/tasks/create-vm.yml
      input_mapping:
        state: config
        image: downloaded-product
```

!!! note "Defaults for tasks"
    We do not explicitly set the default parameters
    for `create-vm` in this example.
    Because `opsman.yml` is the default input to
    `OPSMAN_CONFIG_FILE`, it is redundant 
    to set this param in the pipeline. 
    Refer to the [task definitions][task-reference] for a full range of the 
    available and default parameters.

Set the pipeline.

Before we run the job,
we should [`ensure`][ensure] that `state.yml` is always persisted
regardless of whether the `install-opsman` job failed or passed.
To do this, we can add the following section to the job:

```yaml hl_lines="35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55"
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
    - task: prepare-tasks-with-secrets
      file: platform-automation-tasks/tasks/prepare-tasks-with-secrets.yml
      input_mapping:
        tasks: platform-automation-tasks
      output_mapping:
        tasks: platform-automation-tasks
      params:
        CONFIG_PATHS: config
    - task: download-product        
      image: platform-automation-image
      file: platform-automation-tasks/tasks/download-product.yml
      params:
        CONFIG_FILE: download-ops-manager.yml
    - task: create-vm
      image: platform-automation-image
      file: platform-automation-tasks/tasks/create-vm.yml
      input_mapping:
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
              FILE_DESTINATION_PATH: state.yml
              GIT_AUTHOR_EMAIL: "pcf-pipeline-bot@example.com"
              GIT_AUTHOR_NAME: "Platform Automation Toolkit Bot"
              COMMIT_MESSAGE: 'Update state file'
          - put: config
            params:
              repository: config-commit
              merge: true
```

Set the pipeline one final time,
run the job, and see it pass.

```bash
fly -t control-plane set-pipeline \
    -p foundation \
    -c pipeline.yml
```

Commit the final changes to your repository.

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
