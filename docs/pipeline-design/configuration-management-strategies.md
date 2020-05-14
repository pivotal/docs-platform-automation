# Configuration Management Strategies

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
[Install Ops Man How to Guide][install-how-to] and the
[Upgrading an Existing Ops Manager How to Guide][upgrade-how-to].

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
from a foundation specific vars file, Credhub, Git repository, etc.
This approach is very similar to the Single Repository for Each Foundation
described above,
except that variables are loaded in from external sources.

The variable source may be loaded in a number of ways. For example,
it may be loaded from a separate foundation specific Git repository,
a foundation specific subdirectory in the configuration source, 
or even a foundation specific vars file found in the base Git configuration.

This strategy can reduce the number of overall configuration files
and configuration repositories in play,
and can reduce foundation drift (as the basic configuration is being pulled 
from a single master source).
However,
configuration management and secrets handling
can quickly become more challenging.

**This is the strategy used in our [Reference Pipeline][reference-pipeline]**

For an example repo structure using this strategy,
see the [config repo][reference-pipeline-config]
used by the [Reference Pipeline][reference-pipeline] and the [Resources Pipeline][reference-resources]



## Advanced Pipeline Design

### Matching Resource Names and Input Names

Alternatively, we can create resources that match the input names
on our tasks and bypass the need for using `input_mapping`.
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
