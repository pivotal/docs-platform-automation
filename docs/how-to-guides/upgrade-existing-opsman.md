# Writing a Pipeline to Upgrade an Existing Ops Manager

## Prerequisites

Over the course of this guide,
we're going to use Platform Automation for PCF
to create a [pipeline][concourse-pipeline]
using [Concourse][concourse].

Before we get started, you'll need a few things ready to go:

1. A running Ops Manager VM that you would like to upgrade
1. A Concourse instance
   with access to a Credhub instance
   and to the Internet
1. Github.com account
1. Read/write credentials and bucket name for an S3 bucket
1. An account on [https://network.pivotal.io][pivnet] (Pivnet)
1. A MacOS workstation
    - with Docker installed
    - and a text editor you like
    - a terminal emulator you like
    - a browser that works with Concourse,
      like Firefox or Chrome
    - and `git`

!!! info "IaaS"
    It doesn't actually matter what IaaS your Ops Manager is running on,
    as long as your Concourse can connect to it.
    Pipelines built with Platform Automation can be platform-agnostic.

It will be very helpful to have a basic familiarity with the following. If you don't have basic familiarity with all these things,
that's okay.
We'll explain some basics,
and link to resources to learn more:

- the bash terminal
- [git][git]
- [YAML][yaml]
- [Concourse][concourse]


!!! info "A note on the prerequisites"
    <p>While this guide uses Github to provide a git remote,
    and an S3 bucket as a blobstore,
    Platform Automation supports arbitrary git providers
    and S3-compatible blobstores.
    <p>If you need to use an alternate one,
    that's okay.
    <p>We picked specific examples
    so we could describe some steps in detail.
    Some details may be different
    if you follow along with different providers.
    If you're comfortable navigating those differences on your own,
    go for it!
    <p>Similarly, in this guide, we assume the MacOS operating system.
    This should all work fine on Linux, too,
    but there might be differences in the paths you'll need to figure out.

## Creating a Concourse Pipeline

Platform Automation's tasks and image are meant to be used in a Concourse pipeline.
So, let's make one.

Using your bash command-line client,
create a directory to keep your pipeline files in, and `cd` into it.

```bash
mkdir platform-automation-pipelines
cd !$
```

!!! tip ""`!$`""
    `!$` is a bash shortcut.
    Pronounced "bang, dollar-sign,"
    it means "use the last argument from the most recent command."
    In this case, that's the directory we just created!
    This is not a Platform Automation thing,
    this is just a bash tip dearly beloved
    of at least one Platform Automator.

Before we get started with the pipeline itself,
we'll gather some variables in a file
we can use throughout our pipeline.

Open your text editor and create `vars.yml`.
Here's what it should look like to start, we can add things to this as we go:

```yaml
platform-automation-bucket: your-bucket-name
credhub-server: https://your-credhub.example.com
opsman-url: https://pcf.foundation.example.com
```

!!! info
    This example assumes that you're using DNS and hostnames.
    You can use IP addresses for all these resources instead,
    but you still need to provide the information as a URL,
    f.ex `https://120.121.123.124`

Now, create a file called `pipeline.yml`.

!!! info
    We'll use `pipeline.yml` in our examples throughout this guide.
    However, you may create multiple pipelines over time.
    If there's a more sensible name for the pipeline you're working on,
    feel free to use that instead.

Write this at the top, and save the file. This is [YAML][yaml] for "the start of the document. It's optional, but traditional:

```yaml

---
```

Now you have a pipeline file! Nominally!
Well, look.
It's valid YAML, at least.

### Getting `fly`

Let's try to set it as a pipeline with [`fly`][concourse-fly],
the Concourse command-line Interface (CLI).

First, check if we've got `fly` installed at all:

```bash
fly -v
```

If it gives you back a version number, great!
Skip ahead to [Setting The Pipeline](#setting-the-pipeline)

If it says something like `-bash: fly: command not found`,
we have a little work to do; we've got to get `fly`.

Navigate to the address for your Concourse instance in a web browser.
At this point, you don't even need to be signed in!
If there are no public pipelines, you should see something like this:

![Get Fly][fly-download-image]

If there _are_ public pipelines,
or if you're signed in and there are pipelines you can see,
you'll see something similar in the lower-right hand corner.

Click the icon for your OS and save the file,
`mv` the resulting file to somewhere in your `$PATH`,
and use `chmod` to make it executable:

!!! info "A note on command-line examples"
    Some of these, you can copy-paste directly into your terminal.
    Some of them won't work that way,
    or even if they did, would require you to edit them to replace our example values
    with your actual values.
    We recommend you type all of the bash examples in by hand,
    substituting values, if necessary, as you go.
    Don't forget that you can often hit the `tab` key
    to auto-complete the name of files that already exist;
    it makes all that typing just a little easier,
    and serves as a sort of command-line autocorrect.

```bash
mv ~/Downloads/fly /usr/local/bin/fly
chmod +x !$
```

Congrats! You got `fly`.

!!! info "Okay but what did I just do?"
    FAIR QUESTION. You downloaded the `fly` binary,
    moved it into bash's PATH,
    which is where bash looks for things to execute
    when you type a command,
    and then added permissions that allow it to be e`x`ecuted.
    Now, the CLI is installed -
    and we won't have to do all that again,
    because `fly` has the ability to update itself,
    which we'll get into later.

### Setting The Pipeline

Okay _now_ let's try to set our pipeline with `fly`, the Concourse CLI.

`fly` keeps a list of Concourses it knows how to talk to.
Let's see if the Concourse we want is already on the list:

```bash
fly targets
```

If you see the address of the Concourse you want to use in the list,
note down its name, and use it in the login command:

```bash
fly -t control-plane login
```

!!! info "Control-plane?"
    We're going to use the name `control-plane`
    for our Concourse in this guide.
    It's not a special name,
    it just happens to be the name
    of the Concourse we want to use in our target list.

If you don't see the Concourse you need, you can add it with the `-c` (`--concourse-url`)flag:

```bash
fly -t control-plane login -c https://your-concourse.example.com
```

You should see a login link you can click on
to complete login from your browser.

!!! tip "Stay on target"
    <p>The `-t` flag sets the name when used with `login` and `-c`.
    In the future, you can leave out the `-c` argument.
    <p>If you ever want to know what a short flag stands for,
    you can run the command with `-h` (`--help`) at the end.

Pipeline-setting time!
We'll use the name "foundation" for this pipeline,
but if your foundation has an actual name, use that instead.

```bash
fly -t control-plane set-pipeline -p foundation -c pipeline.yml
```

It should say `no changes to apply`,
which is fair, since we gave it an empty YAML doc.

!!! info "Version discrepancy"
    If `fly` says something about a "version discrepancy,"
    "significant" or otherwise, just do as it says:
    run `fly sync` and try again.
    `fly sync` automatically updates the CLI
    with the version that matches the Concourse you're targeting.
    Useful!

### Your First Job

Let's see Concourse actually _do_ something, yeah?

Add this to your `pipeline.yml`, starting on the line after the `---`:

```yaml
wait: no nevermind let's get version control first
```

Good point. Don't actually add that to your pipeline config yet.
Or if you have, delete it, so your whole pipeline looks like this again:

```yaml

---
```

Reverting edits to our pipeline is something we'll probably want to do again.
This is one of many reasons we want to keep our pipeline under version control.

So let's make this directory a git repo!

#### But First, `git init`

`git` should come back with information about the commit you just created:

```bash
git init
git commit --allow-empty -m "Empty initial commit"
```

If it gives you a config error instead,
you might need to configure `git` a bit.
Here's a [good guide][git-first-time-setup]
to initial setup.
Get that done, and try again.

Now we can add our `pipeline.yml`,
so in the future it's easy to get back to that soothing `---` state.

```bash
git add pipeline.yml vars.yml
git commit -m "Add upgrade-opsman-pipeline and starter vars"
```

Let's just make sure we're all tidy:

```bash
git status
```

`git` should come back with `nothing to commit, working tree clean`.

Great. Now we can safely make changes.

!!! tip "Git commits"
    <p>`git` commits are the basic unit of code history.
    <p>Making frequent, small, commits with good commit messages
    makes it _much easier_ to figure out why things are the way they are,
    and to return to the way things were in simpler, better times.
    Writing short commit messages that capture the _intent_ of the change
    (in an imperative style) can be tough,
    but it really does make the pipeline's history much more legible,
    both to future-you,
    and to current-and-future teammates and collaborators.

#### The Test Task

Platform Automation comes with a [`test`][test] task
meant to validate that it's been installed correctly.
Let's use it to get setup.

Add this to your `pipeline.yml`, starting on the line after the `---`:

```yaml
jobs:
- name: test
  plan:
    - task: test
      image: platform-automation-image
      file: platform-automation-tasks/tasks/test.yml
```

If we try to set this now, Concourse will take it:

```bash
fly -t control-plane set-pipeline -p foundation -c pipeline.yml
```

Now we should be able to see our `upgrade-opsman` pipeline
in the Concourse UI.
It'll be paused, so click the "play" button to unpause it.
Then, click in to the gray box for our `test` job,
and hit the "plus" button to schedule a build.

It should error immediately, with `unknown artifact source: platform-automation-tasks`.
We didn't give it a source for our task file.

We've got a bit of pipeline code that Concourse accepts.
Before we start doing the next part,
this would be a good moment to make a commit:

```bash
git add pipeline.yml
git commit -m "Add (nonfunctional) test task"
```

With that done,
we can try to get the inputs we need
by adding `get` steps to the plan
before the task, like so:

```yaml  hl_lines="4 5 6 7 8 9 10 11 12 13"
jobs:
- name: test
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
    - task: test
      image: platform-automation-image
      file: platform-automation-tasks/tasks/test.yml
```

If we try to `fly set` this,
`fly` will complain about invalid resources.

To actually make the `image` and `file` we want to use available,
we'll need some Resources.

#### Adding Resources

Resources are Concourse's main approach to managing artifacts.
We need an image, and the tasks directory -
so we'll tell Concourse how to get these things by declaring Resources for them.

In this case, we'll be downloading the image and the tasks directory from Pivnet.
Before we can declare the resources themselves,
we have to teach Concourse to talk to Pivnet.
(Many resource types are built in, but this one isn't.)

Add the following to your pipeline file.
We'll put it above the `jobs` entry.

```yaml
resource_types:
- name: pivnet
  type: docker-image
  source:
    repository: pivotalcf/pivnet-resource
    tag: latest-final
resources:
- name: platform-automation
  type: pivnet
  source:
    product_slug: platform-automation
    api_token: ((pivnet-refresh-token))
```

The API token is a credential,
which we'll pass via the command-line when setting the pipeline,
so we don't accidentally check it in.

Grab a refresh token from your [Pivnet profile][pivnet-profile]
and clicking "Request New Refresh Token."
Then use that token in the following command:

!!! tip "Keep it secret, keep it safe"
    Bash commands that start with a space character
    are not saved in your history.
    This can be very useful for cases like this,
    where you want to pass a secret,
    but don't want it saved.
    Commands in this guide that contain a secret
    start with a space, which can be easy to miss.

```bash
# note the space before the command
 fly -t control-plane set-pipeline \
     -p foundation \
     -c pipeline.yml \
     -v pivnet-refresh-token=your-api-token
```

!!! warning Getting Your Pivnet Token Expires It
    When you get your Pivnet token as described above,
    any previous Pivnet tokens you may have gotten will stop working.
    If you're using your Pivnet refresh token anywhere,
    retrieve it from your existing secret storage rather than getting a new one,
    or you'll end up needing to update it everywhere it's used.

Go back to the Concourse UI and trigger another build.
This time, it should pass.

Commit time!

```bash
git add pipeline.yml
git commit -m "Add resources needed for test task"
```

We'd rather not pass our Pivnet token
every time we need to set the pipeline.
Fortunately, Concourse can integrate
with secret storage services.

Let's put our API token in Credhub so Concourse can get it.

First we'll need to login:

!!! info "Backslashes in bash examples"
    The following example has been broken across multiple lines
    by using backslash characters (`\`) to escape the newlines.
    We'll be doing this a lot to keep the examples readable.
    When you're typing these out,
    you can skip that and just put it all on one line.

```bash
# again, note the space at the start
 credhub login --server example.com \
         --client-id your-client-id \
         --client-secret your-client-secret
```

!!! info "Logging in to credhub"
    Depending on your credential type,
    you may need to pass `client-id` and `client-secret`,
    as we do above,
    or `username` and `password`.
    We use the `client` approach because that's the credential type
    that automation should usually be working with.
    Nominally, a username represents a person,
    and a client represents a system;
    this isn't always exactly how things are in practice.
    Use whichever type of credential you have in your case.
    Note that if you exclude either set of flags,
    Credhub will interactively prompt for `username` and `password`,
    and hide the characters of your password when you type them.
    This method of entry can be better in some situations.

Then, we can set the credential name
to the path [where Concourse will look for it][concourse-credhub-lookup-rules]:

```bash
# note the starting space
 credhub set \
         --name /concourse/your-team-name/pivnet-refresh-token \
         --type value \
         --value your-credhub-refresh-token
```

Now, let's set that pipeline again,
without passing a secret this time.

```bash
fly -t control-plane set-pipeline \
    -p foundation \
    -c pipeline.yml
```

This should succeed,
and the diff Concourse shows you should replace the literal credential
with `((pivnet-refresh-token))`.

Visit the UI again and re-run the test job;
this should also succeed.

#### Exporting The Installation

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

Now lets write an `env.yml` for your Ops Manager.

`env.yml` holds authentication and target information
for a particular Ops Manager.

An example `env.yml` is shown below.
As mentioned in the comment,
`decryption-passphrase` is required for `import-installation`,
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

In order to perform interpolation in one of our input files,
we'll need the [`credhub-interpolate` task][credhub-interpolate]
Earlier, we relied on Concourse's native integration with Credhub for interpolation.
That worked because we needed to use the variable
in the pipeline itself, not in one of our inputs.


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
        INTERPOLATION_PATHS: foundation # contains env.yml
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
git add upgrade-opsman-pipeline vars.yml
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
      INTERPOLATION_PATHS: foundation
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
      INTERPOLATION_PATHS: foundation
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
