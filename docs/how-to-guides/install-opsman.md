# Writing a Pipeline to Install OpsManager

{% include ".getting-started.md" %}

#### Download OpsManager product

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
- name: install-opsmanager
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
      file: platform-automation-tasks/tasks/export-installation.yml
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

`download-ops-man.yml` holds creds for communicating with Pivnet,
and uniquely identifies an Ops Manager image to download.

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

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}