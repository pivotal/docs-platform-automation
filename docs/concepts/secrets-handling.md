## Using a Secrets Store to Store Credentials
Secrets stores, such as Credhub, can be used to store secure properties that you don't want committed into a config file.
Within your pipeline, the config file can then reference that secrets store value for runtime evaluation.

Platform Automation Tasks contains two tasks to help with retrieving these credentials in the tasks that use them:

1. The [`prepare-tasks-with-secrets`](#using-prepare-tasks-with-secrets) task can be used with any Concourse supported [secrets store][concourse-secrets-handling].
2. The [`credhub-interpolate`](#using-credhub-interpolate) task can only be used with Credhub.

### Using prepare-tasks-with-secrets
The [`prepare-tasks-with-secrets`][prepare-tasks-with-secrets] task takes a set of tasks
and modifies them to include environment variables referencing the secrets found in the provided config files.
This allows use of the native [Concourse secrets handling][concourse-secrets-handling]
and provides support for any secrets store Concourse supports.

The [`prepare-tasks-with-secrets`][prepare-tasks-with-secrets] task replaces the [credhub-interpolate][credhub-interpolate] task
and provides the following benefits:

* Support for all native Concourse secrets stores including Credhub and Vault.
* Credhub credentials are no longer required by the task so they can be completely handled by concourse.
* Credentials are no longer written to disk which alleviates some security concerns.

The [`prepare-tasks-with-secrets`][prepare-tasks-with-secrets] task can be used two ways:

* Adding to a pipeline without an already implemented credhub-interpolate task
* [Replacing an already implemented credhub-interpolate task](#replacing-credhub-interpolate-with-prepare-tasks-with-secrets)

!!! info "All Secrets Must Exist"
    If using `prepare-tasks-with-secrets`, _all secrets_ must exist in either a secrets store or a vars file.
    If a vars file is used in the subsequent task, it is required by `prepare-tasks-with-secrets`.
    This will prevent those credentials from being added as environment variables to the task
    resulting in Concourse being unable to find them in the secrets store.

To understand how `prepare-tasks-with-secrets` modifies the Platform Automation tasks,
below is an example of how a task will be changed:

1. Authenticate with your credhub instance.
2. Generate a username and password:
        ```bash
        credhub generate --name="/concourse/:team_name/:pipeline_name/vcenter_login" --type=user --username=some-user
        ```
3. Create a director configuration file that references the properties.
       ```yaml
       properties-configuration:
         iaas_configuration:
           vcenter_host: ((vcenter_host))
           vcenter_username: ((vcenter_login.username))
           vcenter_password: ((vcenter_login.password))
       ```

4. (Optional) Create vars files with additional credentials not stored in the secrets store.

    This is not recommended as it is more secure to store credentials in the secrets store.
    If using multiple foundations, there are some cases where 
    a foundation-specific key might not be a credential,
    but should be extracted to allow reuse of the config file between foundations.
    If using a single config file for multiple foundations, 
    vars files may be used instead of storing those non-credentials in a secrets store.

    For example:
       ```yaml
       vcenter_host: vcenter.example.com
       ```

5. Configure your pipeline to use the [`prepare-tasks-with-secrets`][prepare-tasks-with-secrets] task.

    * The `config` input is required and is a directory that contains your configuration file from (3).
    * The `tasks` input is required and is the set of tasks that will be modified.
    * The `vars` input and `VARS_PATHS` param are _only_ required
      if vars files are being used in subsequent tasks
    * The `output_mapping` section is required and is where the modified tasks will be.

    The declaration within a pipeline might look like:
       ```yaml
       - task: prepare-tasks-with-secrets
         file: platform-automation-tasks/tasks/prepare-tasks-with-secrets.yml
         input_mapping:
           tasks: platform-automation-tasks
           config: deployments
           vars: deployments  # required only if using vars
         output_mapping:
           tasks: platform-automation-tasks
         params:
           CONFIG_PATHS: ((foundation))/config
           VARS_PATHS: ((foundation))/vars # required only if using vars
       ```

    !!! info
        Unlike with [`credhub-interpolate`][credhub-interpolate], there is no concept of `SKIP_MISSING`.
        As such, if there are credentials that will be filled in future jobs by vars files,
        those vars files must be provided in the `vars` input and the `VARS_PATHS` param.

     This task will replace all of the tasks provided in the `tasks` input with the modified tasks.
     The modified tasks include an extended `params` section with the secret references detected from the config files.

6. Use the modified tasks in future jobs.
   When using the modified tasks in the rest of the pipeline,
   they can be used alone without the need for vars files
   as all credentials will be pulled from the secrets store.

What the `prepare-tasks-with-secrets` task is doing internally is something like the following. 
Given an original task and the previously provided config/vars files:

```yaml
# Original Platform Automation Task
platform: linux

inputs:
- name: platform-automation-tasks
- name: config # contains the director configuration file
- name: env # contains the env file with target OpsMan Information
- name: vars # variable files to be made available
  optional: true
- name: secrets
  # secret files to be made available
  # separate from vars, so they can be store securely
  optional: true
- name: ops-files # operations files to custom configure the product
  optional: true

params:
  VARS_FILES:
  # - Optional
  # - Filepath to the Ops Manager vars yaml file
  # - The path is relative to root of the task build,
  #   so `vars` and `secrets` can be used.

  OPS_FILES:
  # - Optional
  # - Filepath to the Ops Manager operations yaml files
  # - The path is relative to root of the task build

  ENV_FILE: env.yml
  # - Required
  # - Filepath of the env config YAML
  # - The path is relative to root of the `env` input

  DIRECTOR_CONFIG_FILE: director.yml
  # - Required
  # - Filepath to the director configuration yaml file
  # - The path is relative to the root of the `config` input

run:
  path: platform-automation-tasks/tasks/configure-director.sh
```

The `prepare-tasks-with-secrets` task will modify the original task to have the credentials found in `director.yml` embedded in the `params` section.
Any credentials found in the `vars.yml` file will not be included in the modified task.
The `params` added will have a prefix of `OM_VAR`, so there are no collisions.
The task is a programmatically modified YAML file, so the output loses the comments and keys are sorted.

```yaml
# prepare-job-with-secrets Generated Task
inputs:
- name: platform-automation-tasks
- name: config
- name: env
- name: vars
  optional: true
- name: secrets
  optional: true
- name: ops-files
  optional: true

params:
  DIRECTOR_CONFIG_FILE: director.yml
  ENV_FILE: env.yml
  OM_VAR_vcenter_password: ((vcenter_password))
  OM_VARS_ENV: OM_VAR
  OPS_FILES:
  VARS_FILES:

platform: linux

run:
  path: platform-automation-tasks/tasks/configure-director.sh
```

#### Replacing credhub-interpolate with prepare-tasks-with-secrets
If you already have implemented the [`credhub-interpolate`][credhub-interpolate] task within your pipeline,
this solution should be a _drop in replacement_ if you are not using vars files.

If you are using vars files, the `vars` input and the `VARS_PATHS` param will also need to be set on the `prepare-tasks-with-secrets` task.

For example, if the existing `credhub-interpolate` task looks like this:

{% code_snippet 'examples', 'credhub-interpolate-usage' %}

In the task definition (above), you've had to define the prefix and Credhub authorization credentials.
The new `prepare-tasks-with-secrets` task uses concourse's native integration with Credhub (and other credential managers).
The above definition can be replaced with the following:

```yaml
- task: prepare-tasks-with-secrets
  file: testing-secrets/task.yml
  input_mapping:
    tasks: platform-automation-tasks
    config: deployments
    vars: deployments  # required only if using vars
  output_mapping:
    tasks: platform-automation-tasks
  params:
    CONFIG_PATHS: ((foundation))/config
    VARS_PATHS: ((foundation))/vars # required only if using vars
```

!!! info "If Using Vars Files"
    If using vars files in subsequent tasks, the `vars` input and the `VARS_PATHS` param must be used to prevent
    interpolation errors in those subsequent tasks.

Notice in the above:

* The `output_mapping`, which is required.
  This will replace all `platform-automation-tasks` with the tasks that we have modified.
  The modification now includes an extended `params` that now includes the secret references detected from the config files.
* The `INTERPOLATION_PATHS` is now `CONFIG_PATHS`.
  The concept of reading the references from the config files is still here,
  but no interpolation actually happens.
* The `PREFIX` is no longer defined or provided.
  Since the tasks are using concourse's native credential management, the lookup path is predetermined.
  For example, `/concourse/:team_name/:cred_name` or `/concourse/:team_name/:pipeline_name/:cred_name`.

###  Using credhub-interpolate
The [credhub-interpolate][credhub-interpolate] task can only be used with Credhub.

**It is recommended to use the [prepare-tasks-with-secrets][prepare-tasks-with-secrets] task instead.**

An example workflow would be storing an SSH key.

1. Authenticate with your credhub instance.
2. Generate an ssh key: `credhub generate --name="/concourse/:team_name/:pipeline_name/opsman_ssh_key" --type=ssh`
3. Create an [Ops Manager configuration][opsman-config] file that references the name of the property.

```yaml
opsman-configuration:
  azure:
    ssh_public_key: ((opsman_ssh_key.public_key))
```

4. Configure your pipeline to use the [credhub-interpolate][credhub-interpolate] task.
   It takes an input called `files`, which should contain your configuration file from (3).

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
      # depending on credhub configuration
      # ether CA cert or secret are required
      CREDHUB_CA_CERT: ((credhub_ca_cert))
      CREDHUB_SECRET: ((credhub_secret))

      # all required
      CREDHUB_CLIENT: ((credhub_client))
      CREDHUB_SERVER: ((credhub_server))
      PREFIX: /concourse/:team_name/:pipeline_name
      SKIP_MISSING: true  
```

Notice the `PREFIX` has been set to `/concourse/:team_name/:pipeline_name`, the path prefix defined for your cred in (2).
This allows the config file to have values scoped, for example, per foundation.
`params` should be filled in by the credhub created with your Concourse instance.

!!! info
    You can set the param `SKIP_MISSING:false` to enforce strict checking of 
    your vars files during intrpolation. This is true by default to support 
    credential management from multiple sources. For more information, see the 
    [Multiple Sources](#credub-interpolate-and-vars-files) section.

This task will reach out to the deployed credhub and fill in your entry references and return an output
named `interpolated-files` that can then be read as an input to any following tasks.

Our configuration will now look like

```yaml
opsman-configuration:
 azure:
   ssh_public_key: ssh-rsa AAAAB3Nz...
```

!!! info 
    If using this you need to ensure the concourse worker can talk to credhub so depending
    on how you deployed credhub and/or worker this may or may not be possible.
    This inverts control that now workers need to access credhub vs
    default is atc injects secrets and passes them to the worker.

## Defining Multiline Certificates and Keys in Config Files
There are three ways to include certificates in the yaml files that are used by Platform Automation tasks.

1. Direct inclusion in yaml file

    ```yaml
    # An incomplete base.yml response from om staged-config
    product-name: cf

    product-properties:
      .uaa.service_provider_key_credentials:
        value:
          cert_pem: |
            -----BEGIN CERTIFICATE-----
            ...<Some Cert>...
            -----END CERTIFICATE-----
          private_key_pem: |
            -----BEGIN RSA PRIVATE KEY-----
            ...<Some Private Key>...
            -----END RSA PRIVATE KEY-----

      .properties.networking_poe_ssl_certs:
        value:
          -
            certificate:
              cert_pem: |
                -----BEGIN CERTIFICATE-----
                ...<Some Cert>...
                -----END CERTIFICATE-----
              private_key_pem: |
                -----BEGIN RSA PRIVATE KEY-----
                ...<Some Private Key>...
                -----END RSA PRIVATE KEY-----
    ```

1. Secrets Manager reference in yaml file

    ```yaml
    # An incomplete base.yml
    product-name: cf

    product-properties:
      .uaa.service_provider_key_credentials:
        value:
          cert_pem: ((uaa_service_provider_key_credentials.certificate))
          private_key_pem: ((uaa_service_provider_key_credentials.private_key))

      .properties.networking_poe_ssl_certs:
        value:
          -
            certificate:
              cert_pem: ((networking_poe_ssl_certs.certificate))
              private_key_pem: ((networking_poe_ssl_certs.private_key))
    ```

    This example assumes the use of Credhub.

    Credhub supports a `--type=certificate` credential type
    which allows you to store a certificate and private key pair under a single name.
    The cert and key can be stored temporarily in local files
    or can be passed directly on the command line.

    An example of the file storage method:

    ```bash
    credhub set --type=certificate \
      --name=uaa_service_provider_key_credentials \
      --certificate=./cert.pem \
      --private=./private.key
    ```

1. Using vars files

    Vars files are a mix of the two previous methods.
    The cert/key is defined inline in the vars file:

    ```yaml
    #vars.yml
    uaa_service_provider_key_credentials_cert_pem: |
      -----BEGIN CERTIFICATE-----
      ...<Some Cert>...
      -----END CERTIFICATE-----
    uaa_service_provider_key_credentials_private_key: |
      -----BEGIN RSA PRIVATE KEY-----
      ...<Some Private Key>...
      -----END RSA PRIVATE KEY-----
    networking_poe_ssl_certs_cert_pem: |
      -----BEGIN CERTIFICATE-----
      ...<Some Cert>...
      -----END CERTIFICATE-----
    networking_poe_ssl_certs_private_key: |
      -----BEGIN RSA PRIVATE KEY-----
      ...<Some Private Key>...
      -----END RSA PRIVATE KEY-----
    ```

    and referenced as a `((parameter))` in the `base.yml`

    ```yaml
    # An incomplete base.yml
    product-name: cf

    product-properties:
      .uaa.service_provider_key_credentials:
        value:
          cert_pem: ((uaa_service_provider_key_credentials_cert_pem))
          private_key_pem: ((uaa_service_provider_key_credentials_private_key))

      .properties.networking_poe_ssl_certs:
        value:
          -
            certificate:
              cert_pem: ((networking_poe_ssl_certs_cert_pem))
              private_key_pem: ((networking_poe_ssl_certs_private_key))
    ```

## Storing values for Multi-foundation
### Concourse Supported Secrets Store
If you have multiple foundations, store relevant keys to that foundation in a different pipeline path,
and Concourse will read those values in appropriately.
If sharing the same `base.yml` across foundations, it is recommended to have a different pipeline per foundation.

### Vars Files
Vars files can be used for your secrets handling. 
They are **not** recommended, but are sometimes required based on your foundation setup.

Take the example below (which only uses vars files and does not use a secrets store):

{% include ".cf-partial-config.md" %}

In our first foundation, we have the following `vars.yml`, optional for the [`configure-product`][configure-product] task.
```yaml
# vars.yml
cloud_controller_encrypt_key.secret: super-secret-encryption-key
cloud_controller_apps_domain: cfapps.domain.com
```

The `vars.yml` can then be passed to [`configure-product`][configure-product] with `base.yml` as the config file.
The `configure-product` task will then sub the `((cloud_controller_encrypt_key.secret))` and `((cloud_controller_apps_domain))` 
specified in `vars.yml` and configure the product as normal.

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

If deploying more than one foundation, a unique `vars.yml` should be used for each foundation.

### prepare-tasks-with-secrets and Vars Files
Both Credhub and vars files may be used together to interpolate variables into `base.yml`.
This use case is described in the [Using prepare-tasks-with-secrets](#using-prepare-tasks-with-secrets) section.

### credub-interpolate and Vars Files
Both Credhub and vars files may be used together to interpolate variables into `base.yml`.
Using the same example from above: 

{% include ".cf-partial-config.md" %}

We have one parametrized variable that is secret and might not want to have stored in 
a plain text vars file, `((cloud_controller_encrypt_key.secret))`, but `((cloud_controller_apps_domain))` 
is fine in a vars file. In order to support a `base.yml` with credentials from multiple sources (i.e. 
credhub and vars files), you will need to `SKIP_MISSING: true` in the [`credhub-interpolate`][credhub-interpolate] task.
This is enabled by default by the `credhub-interpolate` task.

The workflow would be the same as [Credhub](#concourse-supported-secrets-store), but when passing the interpolated `base.yml` as a config into the
next task, you would add in a [Vars File](#vars-files) to fill in the missing variables.

An example of how this might look in a pipeline (resources not listed), assuming:

- The `((base.yml))` above 
- `((cloud_controller_encrypt_key.secret))` is stored in credhub
- `((cloud_controller_apps_domain))` is stored in `director-vars.yml` 

```yaml
jobs:
- name: example-credhub-interpolate
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
      # depending on credhub configuration
      # ether Credhub CA cert or Credhub secret are required
      CREDHUB_CA_CERT: ((credhub_ca_cert))
      CREDHUB_SECRET: ((credhub_secret))

      # all required
      CREDHUB_CLIENT: ((credhub_client))
      CREDHUB_SERVER: ((credhub_server))
      PREFIX: /concourse/:team_name/:pipeline_name
      SKIP_MISSING: true
- name: example-configure-director
  plan:
  - get:   
  - task: configure-director
    image: platform-automation-image
    file: platform-automation-tasks/tasks/configure-director.yml
    params:
      VARS_FILES: vars/director-vars.yml
      ENV_FILE: env/env.yml
      DIRECTOR_CONFIG_FILE: config/director.yml
```

### credhub-interpolate and Multiple Key Lookups
When using the `credhub-interpolate` task with a Credhub in a single foundation or multi-foundation manner, 
we want to avoid duplicating identical credentials
(duplication makes credential rotation harder). 

In order to have Credhub read in credentials from multiple paths
(not relative to your `PREFIX`), 
you must provide the absolute path to any credentials 
not in your relative path.

For example, using an alternative `base.yml`:
```yaml
# An incomplete yaml response from om staged-config
product-name: cf

product-properties:
  .cloud_controller.apps_domain:
    value: ((cloud_controller_apps_domain))
  .cloud_controller.encrypt_key:
    value:
      secret: ((/alternate_prefix/cloud_controller_encrypt_key.secret))
  .properties.security_acknowledgement:
    value: X
  .properties.cloud_controller_default_stack:
    value: default
```

Let's say in our `job`, we define the prefix as "foundation1".
The parameterized values in the example above will be interpolated as follows:

`((cloud_controller_apps_domain))` uses a relative path for Credhub.
When running `credhub-interpolate`, the task will prepend the `PREFIX`.
This value is stored in Credhub as `/foundation1/cloud_controller_apps_domain`. 

`((/alternate_prefix/cloud_controller_encrypt_key.secret))` (note the leading slash)
uses an absolute path for Credhub. 
When running `credhub-interpolate`, the task will not prepend the prefix.
This value is stored in Credhub at it's absolute path `/alternate_prefix/cloud_controller_encrypt_key.secret`.

Any value with a leading `/` slash will never use the `PREFIX`
to look up values in Credhub. 
Therefore, you can have multiple key lookups in a single interpolate task. 

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}