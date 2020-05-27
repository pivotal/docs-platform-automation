# Writing a Pipeline to Upgrade an Existing Ops Manager

This how-to-guide shows you how to create a pipeline for upgrading an existing Ops Manager VM.
If you don't have an Ops Manager VM, check out [Installing Ops Manager][install-how-to].

{% set upgradeHowTo = True %}
{% include ".getting-started.md" %}

### Exporting The Installation

We're finally in a position to do work!

While ultimately we want to upgrade Ops Manager,
to do that safely we first need to download and persist
an export of the current installation.

!!! warning "Export your installation routinely"
    We _**strongly recommend**_ automatically exporting
    the Ops Manager installation
    and _**persisting it to your blobstore**_ on a regular basis.
    This ensures that if you need to upgrade (or restore!)
    your Ops Manager for any reason,
    you'll have the latest installation info available.
    Later in this tutorial, we'll be adding a time trigger
    for exactly this reason.

Let's switch out the test job
for one that exports our existing Ops Manager's installation state.
We can switch the task out by changing:

- the `name` of the job
- the `name` of the task
- the `file` of the task

[`export-installation`][export-installation]
has an additional required input.
We need the `env` file used to talk to Ops Manager.

We'll write that file and make it available as a resource in a moment,
for now, we'll just `get` it as if it's there.

It also has an additional output (the exported installation).
Again, for now, we'll just write that
like we have somewhere to `put` it.

Finally, while it's fine for `test` to run in parallel,
`export-installation` shouldn't.
So, we'll add `serial: true` to the job, too.

```yaml hl_lines="2 3 15-21"
jobs:
- name: export-installation
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
    - get: env
    - task: export-installation
      image: platform-automation-image
      file: platform-automation-tasks/tasks/export-installation.yml
    - put: installation
      params:
        file: installation/installation-*.zip
```

If we try to `fly` this up to Concourse,
it will again complain about resources that don't exist.

So, let's make them.

The first new resource we need is the env file.
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
to `vars.yml` so we can reference it later,
when we declare the corresponding resource.

```yaml
pipeline-repo: git@github.com:username/your-repo-name
```

Now lets write an `env.yml` for your Ops Manager.

`env.yml` holds authentication and target information
for a particular Ops Manager.

An example `env.yml` for username/password authentication
is shown below with the required properties.
Please reference [Configuring Env][generating-env-file] for the entire list of properties
that can be used with `env.yml`
as well as an example of an `env.yml`
that can be used with UAA (SAML, LDAP, etc.) authentication.

The property `decryption-passphrase` is required for `import-installation`,
and therefore required for `upgrade-opsman`.

If your foundation uses authentication other than basic auth,
please reference [Inputs and Outputs][env]
for more detail on UAA-based authentication.


```yaml
target: ((opsman-url))
username: ((opsman-username))
password: ((opsman-password))
decryption-passphrase: ((opsman-decryption-passphrase))
```

Add and commit the new `env.yml` file:

```bash
git add env.yml
git commit -m "Add environment file for foundation"
git push
```

Now that the env file we need is in our git remote,
we need to add a resource to tell Concourse how to get it as `env`.

Since this is (probably) a private repo,
we'll need to create a deploy key Concourse can use to access it.
Follow [Github's instructions][git-deploy-keys]
for creating a deploy key.

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
- name: env
  type: git
  source:
    uri: ((pipeline-repo))
    private_key: ((plat-auto-pipes-deploy-key.private_key))
    branch: master
```

We'll put the credentials we need in Credhub:

```bash
# note the starting space throughout
 credhub set \
   -n /concourse/your-team-name/foundation/opsman-username \
   -t value -v your-opsman-username
 credhub set \
   -n /concourse/your-team-name/foundation/opsman-password \
   -t value -v your-opsman-password
 credhub set \
   -n /concourse/your-team-name/foundation/opsman-decryption-passphrase \
   -t value -v your-opsman-decryption-passphrase
```

{% include './.paths-and-pipeline-names.md' %}

In order to perform interpolation in one of our input files,
we'll need the [`credhub-interpolate` task][credhub-interpolate]
Earlier, we relied on Concourse's native integration with Credhub for interpolation.
That worked because we needed to use the variable
in the pipeline itself, not in one of our inputs.

We can add it to our job
after we've retrieved our `env` input,
but before the `export-installation` task:

```yaml hl_lines="16-26"
jobs:
- name: export-installation
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
    - get: env
    - task: credhub-interpolate
      image: platform-automation-image
      file: platform-automation-tasks/tasks/credhub-interpolate.yml
      params:
        CREDHUB_CLIENT: ((credhub-client))
        CREDHUB_SECRET: ((credhub-secret))
        CREDHUB_SERVER: https://your-credhub.example.com
        PREFIX: /concourse/your-team-name/foundation
      input_mapping:
        files: env
      output_mapping:
        interpolated-files: interpolated-env
    - task: export-installation
      image: platform-automation-image
      file: platform-automation-tasks/tasks/export-installation.yml
      input_mapping:
        env: interpolated-env
    - put: installation
      params:
        file: installation/installation-*.zip
```

!!! info A bit on "output_mapping"
    <p>The `credhub-interpolate` task for this job
    maps the output from the task (`interpolated-files`)
    to `interpolated-env`.
    <p>This can be used by the next task in the job
    to more explicitly define the inputs/outputs of each task.
    It is also okay to leave the output as `interpolated-files`
    if it is appropriately referenced in the next task

Notice the [input mappings][concourse-input-mapping]
of the `credhub-interpolate` and `export-installation` tasks.
This allows us to use the output of one task
as in input of another.

An alternative to `input_mappings` is discussed in
[Configuration Management Strategies][advanced-pipeline-design].

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
and pass it to `export-installation` as `config`.

The other new resource we need is a blobstore,
so we can persist the exported installation.

We'll add an [S3 resource][s3-resource]
to the `resources` section:

```yaml
- name: installation
  type: s3
  source:
    access_key_id: ((s3-access-key-id))
    secret_access_key: ((s3-secret-key))
    bucket: ((platform-automation-bucket))
    regexp: installation-(.*).zip
```

Again, we'll need to save the credentials in Credhub:

```bash
# note the starting space throughout
 credhub set \
        -n /concourse/your-team-name/s3-access-key-id \
        -t value -v your-bucket-s3-access-key-id
 credhub set \
        -n /concourse/your-team-name/s3-secret-key \
        -t value -v your-s3-secret-key
```

This time (and in the future),
when we set the pipeline with `fly`,
we'll need to load vars from `vars.yml`.

```bash
# note the space before the command
 fly -t control-plane set-pipeline \
     -p foundation \
     -c pipeline.yml \
     -l vars.yml
```

Now you can manually trigger a build, and see it pass.

!!! tip "Bash command history"
    <p>You'll be using this,
    the ultimate form of the `fly` command to set your pipeline,
    for the rest of the tutorial.
    <p>You can save yourself some typing by using your bash history
    (if you did not prepend your command with a space).
    You can cycle through previous commands with the up and down arrows.
    Alternatively,
    Ctrl-r will search your bash history.
    Just hit Ctrl-r, type `fly`,
    and it'll show you the last fly command you ran.
    Run it with enter.
    Instead of running it,
    you can hit Ctrl-r again
    to see the matching command before that.

This is also a good commit point:

```bash
git add pipeline.yml vars.yml
git commit -m "Export foundation installation in CI"
git push
```

### Performing The Upgrade

Now that we have an exported installation,
we'll create another Concourse job to do the upgrade itself.
We want the export and the upgrade in separate jobs
so they can be triggered (and re-run) independently.

We know this new job is going to center
on the [`upgrade-opsman`][upgrade-opsman] task.
Click through to the task description,
and write a new job that has `get` steps
for our platform-automation resources
and all the inputs we already know how to get:

```yaml
- name: upgrade-opsman
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
  - get: env
  - get: installation
```

We should be able to set this with `fly` and see it pass,
but it doesn't _do_ anything other than download the resources.
Still, we can make a commit here:

```bash
git add pipeline.yml
git commit -m "Setup initial gets for upgrade job"
git push
```

!!! tip "Is this really a commit point though?"
    <p>We like frequent, small commits that can be `fly` set and,
    ideally, go green.
    <p>This one doesn't actually do anything though, right?
    Fair, but: setting and running the job
    gives you feedback on your syntax and variable usage.
    It can catch typos, resources you forgot to add or misnamed, etc.
    Committing when you get to a working point helps keeps the diffs small,
    and the history tractable.
    Also, down the line, if you've got more than one pair working on a foundation,
    the small commits help you keep off one another's toes.
    <p>We don't demonstrate this workflow here,
    but it can even be useful to make a commit,
    use `fly` to see if it works,
    and then push it if and only if it works.
    If it doesn't, you can use `git commit --amend`
    once you've figured out why and fixed it.
    This workflow makes it easy to keep what is set on Concourse
    and what is pushed to your source control remote in sync.

Looking over the list of inputs for [`upgrade-opsman`][upgrade-opsman]
we still need three required inputs:

1. `state`
1. `config`
1. `image`

The optional inputs are vars used with the config,
so we'll get to those when we do `config`.

Let's start with the [state file][state].
We need to record the `iaas` we're on
and the ID of the _currently deployed_ Ops Manager VM.
Different IaaS uniquely identify VMs differently;
here are examples for what this file should look like,
depending on your IaaS:

=== "AWS"
    ``` yaml
    --8<-- 'docs/examples/state/aws.yml'
    ```

=== "Azure"
    ``` yaml
    --8<-- 'docs/examples/state/azure.yml'
    ```

=== "GCP"
    ``` yaml
    --8<-- 'docs/examples/state/gcp.yml'
    ```

=== "OpenStack"
    ``` yaml
    --8<-- 'docs/examples/state/openstack.yml'
    ```

=== "vSphere"
    ``` yaml
    --8<-- 'docs/examples/state/vsphere.yml'
    ```

Find what you need for your IaaS,
write it in your repo as `state.yml`,
commit it, and push it:

```bash
git add state.yml
git commit -m "Add state file for foundation Ops Manager"
git push
```

We can map the `env` resource to [`upgrade-opsman`][upgrade-opsman]'s
`state` input once we add the task.

But first, we've got two more inputs to arrange for.

We'll write an [Ops Manager VM Configuration file][opsman-config]
to `opsman.yml`.
The properties available vary by IaaS;
regardless, you can often inspect your existing Ops Manager
in your IaaS's console
(or, if your Ops Manager was created with Terraform,
look at your terraform outputs)
to find the necessary values.

=== "AWS"
    ---excerpt--- "examples/aws-configuration"
=== "Azure"
    ---excerpt--- "examples/azure-configuration"
=== "GCP"
    ---excerpt--- "examples/gcp-configuration"
=== "Openstack"
    ---excerpt--- "examples/openstack-configuration"
=== "vSphere"
    ---excerpt--- "examples/vsphere-configuration"

Alternatively, you can auto-generate your opsman.yml
using a `p-automator` command to output an opsman.yml file
in the directory it is called from. 

=== "AWS"
    ```bash
    docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
      p-automator export-opsman-config \
      --state-file generated-state/state.yml \
      --config-file opsman.yml \
      --aws-region "$AWS_REGION" \
      --aws-secret-access-key "$AWS_SECRET_ACCESS_KEY" \
      --aws-access-key-id "$AWS_ACCESS_KEY_ID"
    ```

=== "Azure"
    ```bash
    docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
      p-automator export-opsman-config \
      --state-file generated-state/state.yml \
      --config-file opsman.yml \
      --azure-subscription-id "$AZURE_SUBSCRIPTION_ID" \
      --azure-tenant-id "$AZURE_TENANT_ID" \
      --azure-client-id "$AZURE_CLIENT_ID" \
      --azure-client-secret "$AZURE_CLIENT_SECRET" \
      --azure-resource-group "$AZURE_RESOURCE_GROUP"
    ```

=== "GCP"
    ```bash
    docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
      p-automator export-opsman-config \
      --state-file generated-state/state.yml \
      --config-file opsman.yml \
      --gcp-zone "$GCP_ZONE" \
      --gcp-service-account-json <(echo "$GCP_SERVICE_ACCOUNT_JSON") \
      --gcp-project-id "$GCP_PROJECT_ID"
    ```

=== "vSphere"
    ```bash
    docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
      p-automator export-opsman-config \
      --state-file generated-state/state.yml \
      --config-file opsman.yml \
      --vsphere-url "$VCENTER_URL" \
      --vsphere-username "$VCENTER_USERNAME" \
      --vsphere-password "$VCENTER_PASSWORD"
    ```

Once you have your config file, commit and push it:

```bash
git add opsman.yml
git commit -m "Add opsman config"
git push
```

Finally, we need the image for the new Ops Manager version.

We'll use the [`download-product`][download-product] task.
It requires a config file to specify which Ops Manager to get,
and to provide Tanzu Network credentials.
Name this file `download-opsman.yml`:

```yaml
---
pivnet-api-token: ((pivnet-refresh-token)) # interpolated from Credhub
pivnet-file-glob: "ops-manager*.ova"
pivnet-product-slug: ops-manager
product-version-regex: ^2\.5\.0.*$
```

You know the drill.

```bash
git add download-opsman.yml
git commit -m "Add download opsman config"
git push
```

Now, we can put it all together:

```yaml hl_lines="16-46"
- name: upgrade-opsman
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
  - get: env
  - get: installation
  - task: credhub-interpolate
    image: platform-automation-image
    file: platform-automation-tasks/tasks/credhub-interpolate.yml
    params:
      CREDHUB_CLIENT: ((credhub-client))
      CREDHUB_SECRET: ((credhub-secret))
      CREDHUB_SERVER: ((credhub-server))
      PREFIX: /concourse/your-team-name/foundation
    input_mapping:
      files: env
    output_mapping:
      interpolated-files: interpolated-configs
  - task: download-opsman-image
    image: platform-automation-image
    file: platform-automation-tasks/tasks/download-product.yml
    params:
      CONFIG_FILE: download-opsman.yml
    input_mapping:
      config: interpolated-configs
  - task: upgrade-opsman
    image: platform-automation-image
    file: platform-automation-tasks/tasks/upgrade-opsman.yml
    input_mapping:
      config: interpolated-configs
      image: downloaded-product
      secrets: interpolated-configs
      state: env
```

!!! note "Defaults for tasks"
    We do not explicitly set the default parameters
    for `upgrade-opsman` in this example.
    Because `opsman.yml` is the default input to `OPSMAN_CONFIG_FILE`,
    `env.yml` is the default input to `ENV_FILE`,
    and `state.yml` is the default input to `STATE_FILE`,
    it is redundant to set this param in the pipeline. 
    Refer to the [task definitions][task-reference] for a full range of the 
    available and default parameters.

Set the pipeline.

Before we run the job,
we should [`ensure`][ensure] that `state.yml` is always persisted
regardless of whether the `upgrade-opsman` job failed or passed.
To do this, we can add the following section to the job:

```yaml hl_lines="49-68"
- name: upgrade-opsman
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
  - get: env
  - get: installation
  - task: credhub-interpolate
    image: platform-automation-image
    file: platform-automation-tasks/tasks/credhub-interpolate.yml
    params:
      CREDHUB_CLIENT: ((credhub-client))
      CREDHUB_SECRET: ((credhub-secret))
      CREDHUB_SERVER: ((credhub-server))
      PREFIX: /concourse/your-team-name/foundation
    input_mapping:
      files: env
    output_mapping:
      interpolated-files: interpolated-configs
  - task: download-opsman-image
    image: platform-automation-image
    file: platform-automation-tasks/tasks/download-product.yml
    params:
      CONFIG_FILE: download-opsman.yml
    input_mapping:
      config: interpolated-configs
  - task: upgrade-opsman
    image: platform-automation-image
    file: platform-automation-tasks/tasks/upgrade-opsman.yml
    input_mapping:
      config: interpolated-configs
      image: downloaded-product
      secrets: interpolated-configs
      state: env
  ensure:
    do:
    - task: make-commit
      image: platform-automation-image
      file: platform-automation-tasks/tasks/make-git-commit.yml
      input_mapping:
        repository: env
        file-source: generated-state
      output_mapping:
        repository-commit: env-commit
      params:
        FILE_SOURCE_PATH: state.yml
        FILE_DESTINATION_PATH: state.yml
        GIT_AUTHOR_EMAIL: "ci-user@example.com"
        GIT_AUTHOR_NAME: "CI User"
        COMMIT_MESSAGE: 'Update state file'
    - put: env
      params:
        repository: env-commit
        merge: true
```

Set the pipeline one final time,
run the job, and see it pass.

```bash
git add pipeline.yml
git commit -m "Upgrade Ops Manager in CI"
git push
```

Your upgrade pipeline is now complete.
You are now free to move on to the next steps of your automation journey.

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
