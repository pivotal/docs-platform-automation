# Writing a Pipeline to Upgrade an Existing Ops Manager

{% set extra_prereq_item="1. a running Ops Manager VM that you would like to upgrade" %}
{% include ".getting-started.md" %} 

#### Exporting The Installation

We're finally in a position to do work!

While ultimately we want to upgrade Ops Manager,
to do that safely we first need to download and persist
an export of the current installation.

!!! warning "export your installation routinely"
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

```yaml hl_lines="2 3 15 16 17 18 19 20 21"
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

`env.yml` holds authentication and target information
for a particular Ops Manager.

An example `env.yml` is shown below.
As mentioned in the comment,
`decryption-passphrase` is required for `import-installation`,
and therefore required for `upgrade-opsman`.

If your foundation uses authentication other than basic auth,
please reference [Inputs and Outputs][env]
for more detail on UAA-based authentication.

Write an `env.yml` for your Ops Manager.

```yaml
target: ((opsman-url))
username: ((opsman-username))
password: ((opsman-password))
decryption-passphrase: ((opsman-decryption-passphrase))
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
- name: env
  type: git
  source:
    uri: ((pipeline-repo))
    private_key: ((plat-auto-pipes-deploy-key))
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

!!! info "Credhub paths and pipeline names"
    <p>Notice that we've added an element to the cred paths;
    now we're using the foundation name.
    <p>If you look at [Concourse's lookup rules,][concourse-credhub-lookup-rules]
    you'll see that it searches the pipeline-specific path
    before the team path.
    Since our pipeline is named for the foundation it's used to manage,
    we can use this to scope access to our foundation-specific information
    to just this pipeline.
    <p>By contrast, the Pivnet token may be valuable across several pipelines
    (and associated foundations),
    so we scoped that to our team.

Earlier, we relied on Concourse's native integration with Credhub for interpolation.
That worked because we needed to use the variable
in the pipeline itself, not in one of our inputs.
In order to perform interpolation in one of our input files,
we'll need the [`credhub-interpolate` task][credhub-interpolate]

We can add it to our job
after we've retrieved our `env` input,
but before the `export-installation` task:

```yaml hl_lines="16 17 18 19 20 21 22 23 24 25 26"
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
        INTERPOLATION_PATH: foundation # contains env.yml
      input_mapping:
        files: env
      output_mapping:
        interpolated-files: interpolated-env
    - task: export-installation
      image: platform-automation-image
      file: platform-automation-tasks/tasks/export-installation.yml
      params:
        ENV_FILE: your/env/path/env.yml
      input_mapping:
        env: interpolated-env
    - put: installation
      params:
        file: installation/installation-*.zip
```

!!! note A bit on "output_mapping"
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

Ironically, we now need to put our `credhub_client` and `credhub_secret` into Credhub,
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
    regexp: foundation/installation-(.*).zip
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
    <p>You can save yourself some typing by using your bash history.
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

Find what you need for your IaaS,
write it in your repo as `foundation/state.yml`,
commit it, and push it:

```bash
git add foundation/state.yml
git commit -m "Add state file for foundation Ops Manager"
git push
```

We can map the env resource to [`upgrade-opsman`][upgrade-opsman]'s
`state` input once we add the task.

But first, we've got two more inputs to arrange for.

Let's do [`config`][opsman-config] next.

We'll write an [Ops Manager VM Configuration file][opsman-config]
to `foundation/opsman.yml`.
The properties available vary by IaaS;
regardless, you can often inspect your existing Ops Manager
in your IaaS's console
(or, if your Ops Manager was created with Terraform,
look at your terraform outputs)
to find the necessary values.

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
about the details of your existing Ops Manager's configuration.
See [the reference docs for this file][opsman-config]
for more details about your options and per-IaaS caveats.

Once you have your config file, commit and push it:

```bash
git add foundation/opsman.yml
git commit -m "Add opsman config"
git push
```

Finally, we need the image for the new Ops Manager version.

We'll use the [`download-product`][download-product] task.
It requires a config file to specify which Ops Manager to get,
and to provide Pivotal Network credentials.
Name this file `foundation/download-opsman.yml`:

```yaml
---
pivnet-api-token: ((pivnet-refresh-token)) # interpolated from Credhub
pivnet-file-glob: "ops-manager*.ova"
pivnet-product-slug: ops-manager
product-version-regex: ^2\.5\.0.*$
```

You know the drill.

```bash
git add foundation/download-opsman.yml
git commit -m "Add download opsman config"
git push
```

Now, we can put it all together:

```yaml hl_lines="16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46"
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
      # A file path that includes env.yml, opsman.yml, download-opsman.yml
      INTERPOLATION_PATH: foundation 
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
    params:
      ENV_FILE: foundation/env.yml
      OPSMAN_CONFIG_FILE: foundation/opsman.yml
      STATE_FILE: foundation/state.yml
```

Set the pipeline.

Before we run the job, 
we should [`ensure`][ensure] that `state.yml` is always persisted
regardless of whether the `upgrade-opsman` job failed or passed.
To do this, we can add the following section to the job:
```yaml hl_lines="49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68"
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
      # A file path that includes env.yml, opsman.yml, download-opsman.yml
      INTERPOLATION_PATH: foundation 
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
    params:
      ENV_FILE: foundation/env.yml
      OPSMAN_CONFIG_FILE: foundation/opsman.yml
      STATE_FILE: foundation/state.yml
  ensure:
    do:
    - task: make-commit
      image: platform-automation-image
      file: platform-automation-tasks/tasks/make-git-commit.yml
      input_mapping:
        repository: env
        file-source: env
      output_mapping:
        repository-commit: env-commit
      params:
        FILE_SOURCE_PATH: foundation/state.yml
        FILE_DESTINATION_PATH: foundation/state.yml
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