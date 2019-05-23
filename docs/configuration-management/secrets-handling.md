##  Using Your Credhub
Credhub can be used to store secure properties that you don't want committed into a config file.
Within your pipeline, the config file can then reference that Credhub value for runtime evaluation.

An example workflow would be storing an SSH key.

1. Authenticate with your credhub instance.
2. Generate an ssh key: `credhub generate --name="/private-foundation/opsman_ssh_key" --type=ssh`
3. Create an [OpsManager configuration][opsmanager configuration] file that references the name of the property.

```yaml
opsman-configuration:
  azure:
    ssh_public_key: ((opsman_ssh_key.public_key))
```

4. Configure your pipeline to use the [credhub interpolate] task.
   It takes an input `files`, which should contain your configuration file from (3).

   The declaration within a pipeline might look like:

```yaml
jobs:
- name: example-job
  plan:
  - get: platform-automation-tasks
  - get: platform-automation-image
  - get: config
  - task: credhub-interpolate
    image: platform-automation-image
    file: platform-automation-tasks/tasks/credhub-interpolate.yml
    input_mapping:
      files: config
    params:
      # all required
      CREDHUB_CA_CERT: ((credhub_ca_cert))
      CREDHUB_CLIENT: ((credhub_client))
      CREDHUB_SECRET: ((credhub_secret))
      CREDHUB_SERVER: ((credhub_server))
      PREFIX: /private-foundation  
```

Notice the `PREFIX` has been set to `/private-foundation`, the path prefix defined for your cred in (2).
This allows the config file to have values scoped, for example, per foundation.
`params` should be filled in by the credhub created with your Concourse instance.

This task will reach out to the deployed credhub and fill in your entry references and return an output
named `interpolated-files` that can then be read as an input to any following tasks.

Our configuration will now look like

```yaml
opsman-configuration:
 azure:
   ssh_public_key: ssh-rsa AAAAB3Nz...
```

!!! info 
    If using this you need to ensure concourse worker can talk to credhub so depending
    on how you deployed credhub and/or worker this may or may not be possible.
    This inverts control that now workers need to access credhub vs
    default is atc injects secrets and passes them to the worker.


## Storing values for Multi-foundation
### Credhub
In the example above, `bosh int` did not replace the ((placeholder_credential)): `((cloud_controller_encrypt_key.secret))`.
For security, values such as secrets and keys should not be saved off in static files (such as an ops file). In order to
rectify this, you can use a secret management tool, such as Credhub, to sub in the necessary values to the deployment
manifest.  

Let's assume basic knowledge and understanding of the
[`credhub-interpolate`][credhub interpolate] task described in the [Secrets Handling][secrets-handling] section
of the documentation.

For multiple foundations, [`credhub-interpolate`][credhub interpolate] will work the same, but `PREFIX` param will
differ per foundation. This will allow you to keep your `base.yml` the same for each foundation with the same
((placeholder_credential)) reference. Each foundation will require a separate [`credhub-interpolate`][credhub interpolate]
task call with a unique prefix to fill out the missing pieces of the template.

### Vars Files
Alternatively, vars files can be used for your secrets handling.

Take the same example from above:

{% include ".cf-partial-config.md" %}

In our first foundation, we have the following `vars.yml`, optional for the [`configure-product`][configure-product] task.
```yaml
# vars.yml
cloud_controller_encrypt_key.secret: super-secret-encryption-key
```

The `vars.yml` could then be passed to [`configure-product`][configure-product] with `base.yml` as the config file.
The task will then sub the `((cloud_controller_encrypt_key.secret))` specified in `vars.yml` and configure the product as normal.

An example of how this might look in a pipeline(resources not listed):
```yaml
jobs:
- name: configure-product
  plan:
  - aggregate:
    - get: platform-automation-image
      params:
        unpack: true
    - get: platform-automation-tasks
      params:
        unpack: true
    - get: configuration
    - get: variable
  - task: configure-product
    image: platform-automation-image
    file: platform-automation-tasks/tasks/configure-product.yml
    input_mapping:
      config: configuration
      env: configuration
      vars: variable
    params:
      CONFIG_FILE: base.yml
      VARS_FILES: vars.yml
      ENV_FILE: env.yml
```

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
