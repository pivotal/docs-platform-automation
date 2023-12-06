# Configuration management strategies

When building pipelines,
there are many possible strategies
for structuring your configuration in source control
as well as in pipeline design.
No single method can cover all situations.
After reading this document,
we hope you feel equipped to select an approach.

## Single Repository for Each Foundation

This is the simplest thing that could possibly work.
It's the default assumed in all our examples,
unless we've articulated a specific reason to choose a different approach.
It entails using a single Git repository for each foundation.

Tracking foundation changes are simple,
getting started is easy,
duplicating foundations is simply a matter of cloning a repository,
and configuration files are not difficult to understand.

This is the strategy used throughout the
[Install Tanzu Operations Manager How-to Guide][install-how-to] and the
[Upgrading an existing Tanzu Operations Manager How-to Guide][upgrade-how-to].

Let's examine an example configuration repository
that uses the "Single Repository for each Foundation" pattern:

```
├── auth.yml
├── pas.yml
├── director.yml
├── download-opsman.yml
├── download-product-configs
│   ├── healthwatch.yml
│   ├── opsman.yml
│   ├── pas-windows.yml
│   ├── pas.yml
│   └── telemetry.yml
├── env.yml
├── healthwatch.yml
├── opsman.yml
└── pas-windows.yml
```

Notice that there is only one subdirectory
and that all other files are at the repositories base directory.
_This minimizes parameter mapping in the platform-automation tasks_.
For example, in the [`configure-director`][configure-director]
step:

---excerpt--- "examples/configure-director-usage"

We map the config files 
to the expected input named `env` of the `configure-director` task.
Because the `configure-director` task's default `ENV` parameter is `env.yml`,
it automatically uses the `env.yml` file in our configuration repo. 
We do not need to explicitly name the `ENV` parameter for the task.
This also works for `director.yml`.

Another option for mapping resources to inputs
is discussed in the [Matching Resource Names and Input Names][matching-resource-names-and-input-names] section.

For reference, here is the `configure-director` task:

---excerpt--- "tasks/configure-director"

## Multiple Foundations with one Repository

Multiple foundations may use a single Git configuration source
but have different variables loaded 
from a foundation specific vars file, Credhub, etc.

This strategy can reduce foundation drift 
and streamline the configuration promotion process between foundations.

**This is the strategy used in our [Reference Pipeline][reference-pipeline]**

### Overview

The [Reference Pipeline][reference-pipeline] uses a public [config repo][ref-config-repo]
with all secrets stored in our Concourse's Credhub.

The design considerations for this strategy as implemented are as follows:

- Prioritization of ease of configuration promotion
  over minimization of configuration
  file duplication between foundations.
- Global, non-public variables can be overwritten by
  foundation-specific variables based on `VARS_FILES` ordering. 
- Product configuration can differ between product versions,
  so the entire configuration file is promoted between foundations.
- No outside tooling or additional preparation tasks
  are required to use this strategy.
  It makes use of only concepts and workflows
  built-in to Platform Automation and Concourse.
- No significant differences between the required setup of foundations.
  
    This doesn't mean that this strategy cannot be used 
    with more complicated differences.
    If the pipelines need to be different for one reason or another,
    you might want the `pipelines` directory to be at the foundation level
    and for the `pipeline.yml` to be foundation-specific.
    
    The Reference Pipeline handles the different environments via a `fly` variable.
    The pipeline set script is found in the [`scripts`][ref-config-update-script] directory.

### Structure

A simplified view of the [config-repo][ref-config-repo] is represented below:

```
├── download-product-pivnet
│   ├── download-opsman.yml
│   └── download-pks.yml
├── foundations
│   ├── config
│   │   ├── auth.yml
│   │   └── env.yml
│   ├── development
│   │   ├── config
│   │   │   ├── director.yml
│   │   │   ├── download-opsman.yml
│   │   │   ├── download-pks.yml
│   │   │   ├── opsman.yml
│   │   │   └── pks.yml
│   │   └── vars
│   │       ├── director.yml
│   │       ├── pks.yml
│   │       └── versions.yml
│   ├── sandbox
│   │   ├── config
│   │   │   ├── director.yml
│   │   │   ├── download-opsman.yml
│   │   │   ├── download-pks.yml
│   │   │   ├── opsman.yml
│   │   │   └── pks.yml
│   │   └── vars
│   │       ├── director.yml
│   │       ├── pks.yml
│   │       └── versions.yml
│   └── vars
│       └── director.yml
├── pipelines
│   ├── download-products.yml
│   └── pipeline.yml
└── scripts
    └── update-reference-pipeline.sh
```

Let's start with the top-level folders:

- `download-product-pivnet` contains config files
  for downloading products from pivnet
  and uploading those products to a blobstore.
- `foundations` contains all of the configuration files
  and variable files for all foundations.
- `pipelines` contains the pipeline files
  for the resources pipeline and the foundation pipelines.
- `scripts` contains the BASH script for setting all of the pipelines.

#### `foundations`

Within the `foundations` folder, we have all of our foundations as well as two additional folders:

- `config` contains any global config files -- in our case, `env.yml` and `auth.yml`.
  These files are used by `om` and their structure is not foundation-dependent.
  As a result, each foundation pipeline fills out the parameterized variables
  from Concourse's credential manager.
- `vars` contains foundation-independent variables for any of the configuration files.
  In this example, all of the foundations are on a single IAAS,
  so the common vars tend to be IAAS-specific.
  These files can also include any other variables determined
  to be consistently the same across foundations.

#### `foundations/<foundation>`

For each foundation, we have two folders:

- `config` contains the configuration files that `om` uses for:
    - Downloading products from a blobstore; specified with the prefix `download-`
    - Configuring a product; specified by `<product-name>.yml`
    - Configuring the BOSH director; specified with `director.yml`
    - Configuring the Tanzu Operations Manager VM; specified with `opsman.yml`
- `vars` contains any foundation-specific variables used by Platform Automation tasks.
  These variables will fill in any variables `((parameterized))` in config files
  that are not stored in Concourse's credential manager.

### Config Promotion Example

In this example, we will be updating PKS from 1.3.8 to 1.4.3.
We will start with updating this tile in our `sandbox` foundation
and then promote the configuration to the `development` foundation.
We assume that you are viewing this example 
from the root of the [Reference Pipeline Config Repo][ref-config-repo].

1. Update `download-product-pivnet/download-pks.yml`:

    ```diff
    - product-version-regex: ^1\.3\..*$
    + product-version-regex: ^1\.4\..*$
    ```

1. Commit this change and run the [resource pipeline][ref-config-resource-pipeline]
which will download the 1.4.3 PKS tile
and make it available on S3.

1. Update the versions file for sandbox:

    ```diff
    - pks-version: 1.3.8
    + pks-version: 1.4.3
    ```

1. Run the `upload-and-stage-pks` job, but do not run the `configure-pks` or `apply-product-changes` jobs.

    This makes it so that the `apply-changes` step won't automatically fail
    if there are configuration changes
    between what we currently have deployed
    and the new tile.

1. Login to the Tanzu Operations Manager UI. If the tile has unconfigured properties:

    1. Manually configure the tile and deploy

    1. Re-export the staged-config:

        ```
        om -e env.yml staged-config --include-credentials -p pivotal-container-service
        ```

    1. Merge the resulting config with the existing `foundations/sandbox/config/pks.yml`.

        Diffing the previous `pks.yml`
        and the new one makes this process much easier.

    1. Pull out new parameterizable variables
       and store them in `foundations/vars/pks.yml` or `foundations/sandbox/vars/pks.yml`,
       or directly into Credhub.
       Note, there may be nothing new to parameterize.
       This is okay, and makes the process go faster.

    1. Commit any changes.

1. Run the `configure-pks` and `apply-product-changes` jobs on the `sandbox` pipeline.

1. Assuming the `sandbox` pipeline is all green,
   copy the `foundations/sandbox/config` folder into `foundations/development/config`.

1. Modify the `foundations/development/vars/versions.yml` and `foundations/development/vars/pks.yml` files
   to have all of the property references that exist in their sandbox counterparts
   as well as the foundation-specific values.

1. Commit these changes and run the `development` pipeline all the way through.

!!! info "A Quicker `development` Deploy Process"
    Since all of the legwork was done manually in the `sandbox` environment
    there is no need to login to the `development` Tanzu Operations Manager environment.

    If there are no configuration changes, the only file that needs to be promoted is `versions.yml`


## Advanced Pipeline Design

### Matching Resource Names and Input Names

As an alternative to `input_mapping`, 
we can create resources that match the input names on our tasks.
Even if these resources map to the same git repository and branch,
they can be declared as separate inputs.

---excerpt--- "examples/input-matched-resources-usage"

As long as those resources have an associated `get: <resource-name>`
in the job, they will automatically be mapped to the inputs of the tasks in that job:

---excerpt--- "examples/configure-director-matched-resources-usage"

!!! warning "Passed Constraints"
     If you have two resources defined with the same git repository, such as env and config,
     and have a passed constraint on only one of them,
     there is a possibility that they will not be at the same SHA for any given job in your pipeline.
     
     Example:
     ```yaml
     - get: config
     - get: env
       passed: [previous-job]
     ```

### Modifying Resources in-place

!!! info "Concourse 5+ Only"
      This section uses a Concourse feature that allows inputs and outputs to have the same name.
      This feature is only available in Concourse 5+. The following does not work with Concourse 4.

In certain circumstances, resources can be modified by one task in a job
for use later in that same job. A few tasks that offer this ability include:

- [credhub-interpolate]
- [prepare-tasks-with-secrets]
- [prepare-image]

For each of these tasks, `output_mapping` can be used to "overwrite"
an input with a modified input for use with tasks later in that job.

In the following example, `prepare-tasks-with-secrets` takes in the
`platform-automation-tasks` input and modifies it for the `download-product`
task. A more in-depth explanation of this can be found on the [secrets-handling][secrets-handling] page.

```yaml
- name: configure-director
  serial: true
  plan:
    - aggregate:
      - get: platform-automation-image
        params:
          unpack: true
      - get: platform-automation-tasks
        params:
          unpack: true
      - get: config
      - get: env
    - task: prepare-tasks-with-secrets
      image: platform-automation-image
      file: platform-automation-tasks/tasks/prepare-tasks-with-secrets.yml
      input_mapping:
        tasks: platform-automation-tasks
      output_mapping:
        tasks: platform-automation-tasks
      params:
        CONFIG_PATHS: config
    - task: download-product
      image: platform-automation-image
      # The following platform-automation-tasks have been modified
      # by the prepare-tasks-with-secrets task
      file: platform-automation-tasks/tasks/download-product.yml
      params:
        CONFIG_FILE: download-ops-manager.yml
```

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
