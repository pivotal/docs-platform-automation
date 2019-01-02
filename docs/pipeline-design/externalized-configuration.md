# Externalized Configuration

## Introduction
Usually, the operator configures the OpsManager or a tile through the web UI.
The targeted OpsManager is considered as the source of truth, meaning
that it holds every aspect of the configuration of a foundation. However, managing the configuration of multiple foundations
through the web UI can be challenging or recreating the foundation over and over can be difficult. This is mainly because:

* avoiding configuration drift among foundations can be difficult
* promoting configuration from one foundation can be difficult
* no explicit versioning on configuration makes it difficult to trace

One pattern emerges to address the above problems and that is to externalize the
configuration.

## What is externalized configuration?
At a high-level, an externalized config is a configuration file that lives
outside of OpsManager. Because the configuration file essentially
configures OpsManager or a tile within OpsManager to a known state, it implies the configuration
file is the source of truth. And since the file is just a plain-text
documentation, it can be easily versioned using a Version Control System (VCS) like git. For multiple foundations,
one approach is to promote the entire configuration file.

## Why use externalized configuration?
**Traceability**

Essentially, the configuration file is a plain-text YAML documentation,
it could be easily versioned using VCS like git. This way operators have
maximum traceability of the state of OpsManager. Every single change of
the configuration can be reviewed and approved.

**Avoiding configuration drift**

As the configuration for a given foundation is essentially code, it is
very easy to take a diff of a plain-text documentation. Or even better,
various tools can compare YAML documentation to ignore the difference
in style, so that even a single character difference can be caught and
prevented if the difference is an accident. Also, all the configuration
files can be centralized and structured to ease the management.

**Configuration promotion**

Since the configuration file is the source of truth, if it is tested on
the sandbox/dev environment, it can be promoted to a production environment
easily. Through the use of [Ops Files][ops-files],
values unique to a specific environment can be the only changes between
different environments while keeping the base configuration the same.

## Using externalized OpsManager configuration
To get started with externalized config for OpsManager, you first create the infrastructure for your installation and install your OpsManager. Next, you extract an OpsManager configuration file from the existing foundation. Once you have the configuration file you can configure OpsManager using that file and/or use the file to promote OpsManager to another foundation. To do this, use the steps outlined below.  

### Create infrastructure and install OpsManager

1. Create the infrastructure for your installation.
To make the infrastructure creation easier, consider using terraform to create the resources needed:

    1. [terraforming-aws][terraforming-aws]
    1. [terraforming-gcp][terraforming-gcp]
    1. [terraforming-azure][terraforming-azure]
    1. [terraforming-vsphere][terraforming-vsphere]
    1. [terraforming-openstack][terraforming-openstack]

    !!! warning
        Do NOT deploy OpsManager using terraform.

        Using terraform to deploy the OpsManager will cause problems when using the
        [upgrade-opsman][upgrade-opsman], [create-vm][create-vm], and
        [delete-vm][delete-vm] commands. If you use terraform to deploy your
        OpsManager, use `terraform-destroy` to remove the OpsManager VM from
        your `tf.state`.

1. [Install your OpsManager][opsman-install-docs]


### Extract configuration for OpsManager
[om] has a command called [staged-director-config], which is used to extract
the OpsManager and the BOSH director configuration from the targeted foundation.

{% include ".missing_fields_opsman_director.md" %}

Sample usage:  
`om --env env.yml staged-director-config > director.yml`  
will give you the whole configuration of OpsManager in a single yml file.
It will look more or less the same as the example above. You can check it
in to your VCS.

The following is an example configuration file for OpsManager that might return
after running this command:
{% code_snippet 'pivotal/platform-automation', 'director-configuration' %}

### Configure OpsManager using configuration file
Now you can modify the settings in the configuration file directly instead of
operating in the web ui. After you finish editing the file, the configuration
file will need to apply back to the OpsManager instance. The command
[configure-director] will do the job.

Sample usage:  
`om --env env.yml configure-director --config director.yml`  


### Promote OpsManager to another foundation
The configuration file is the exact state of a given foundation, it contains
some environment specific properties. You need to manually edit those
properties to reflect the state of the new foundation. Or, when extracting
the configuration file from the foundation, you can use the flag
`--include-placeholders`, it will help to parameterize some variables to
ease the process of adapt for another foundation.

After you are satisfied with the configuration change, you can use [om]
to apply the configuration: `om --env some-other-env.yml configure-director --config adapted-director.yml`


## Using externalized tile configuration
To get started with externalized config for a tile, you must first have a tile deployed on an existing foundation. Then, you extract the tile configuration. Once you have the tile configuration file, you can use ops files to externalize your configuration for multiple foundations. To do this, use the steps outlined below.  

### Upload, stage, and configure tile manually
To do this, complete the following:

1. Upload and Stage your desired tile(s) to the fully deployed OpsManager.
For example, let's use [PAS][PAS] on Vsphere
1. Configure your tile according to the tile's
[install instructions][pas-install-vsphere].

### Extract configuration for the tile
[om] has a command called [staged-config], which is used to extract staged tile
configuration present in the OpsManager UI of the targeted foundation.

Sample usage, using `om` directly and assuming the [PAS][PAS] tile:  
`om --env env.yml staged-config --include-placeholders --product-name cf > tile-config.yml`  

Most tiles will contain the following high level keys:

- network-properties
- product-properties
- resource-config

You can check the file in to your VCS.

For convenience, Platform Automation provides you with two ways to use the
`om staged-config` command. The command can be run as a [task][staged-config]
inside of your pipeline. As an example of how to invoke this for the [PAS][PAS] tile
in your pipeline.yml(resources not listed):
```
jobs:
- name: staged-pas-config
  plan:
  - aggregate:
    - get: pcf-automation-image
      params:
        unpack: true
    - get: pcf-automation-tasks
      params:
        unpack: true
    - get: configuration
    - get: variable
  - task: staged-config
    image: pcf-automation-image
    file: pcf-automation-tasks/tasks/staged-config.yml
    input_mapping:
      env: configuration
    params:
      PRODUCT_NAME: cf
      ENV_FILE: ((foundation))/env/env.yml
      SUBSTITUTE_CREDENTIALS_WITH_PLACEHOLDERS: true
  - put: configuration
    params:
      file: generated-config/cf.yml      
```
This task will connect to the OpsManager defined in your [`env.yml`][env file], download the current staged
configuration of your tile, and put it into a `generated-config` folder in the concourse job. The `put` in
concourse allows you to persist this config outside the concourse container.

Alternatively, this can be run external to concourse by using docker. An example
of how to do this using on the linux/mac command line:

{% include ".docker-import-tile.md" %}

### Using Ops Files for Multi-Foundation

`--include-placeholders` in the `om` command is a vital first step to externalizing
your configuration for multiple foundations. This will search the OpsManager tile
for fields marked as "secrets", and replace those values with
`((placeholder_credentials))`.

In order to fully support multiple foundations, however, a bit more work is
necessary. There are two ways to do this: using [secrets management][multi-foundation-secrets-handling] or ops files.
This section will explain how to support multiple foundations using ops files.

Starting with an **incomplete** [PAS][PAS] config from **vSphere** as an example:

{% include ".cf-partial-config.md" %}

For a single foundation deploy, leaving values such as
`".cloud_controller.apps_domain"` as-is would work fine. For multiple
foundations, this value will be different per deployed foundation. Other values,
such as `.cloud_controller.encrypt_key` have a secret that
already have a placeholder from `om`. If different foundations have different
load requirements, even the values in `resource-config` can be edited using
[ops files][ops-files].

Using the example above, let's try filling in the existing placeholder for
`cloud_controller.apps_domain` in our first foundation.
```yaml
# replace-domain-ops-file.yml
- type: replace
  path: /product-properties/.cloud_controller.apps_domain/value?
  value: unique.foundation.one.domain
```

To test that the ops file will work in your `base.yml`, this can be done locally using `bosh int`:
```bash
 bosh int base.yml -o replace-domain.yml
```

This will output `base.yml` with the replaced(interpolated) values:

{% include ".cf-partial-config-domain-interpolated.md" %}

Anything that needs to be different per deployment can be replaced via ops files as long as the `path:` is correct.

### Multiple Foundations Using Secrets Handling

#### Credhub
In the example above, `bosh int` did not replace the ((placeholder_credential)): `((cloud_controller_encrypt_key.secret))`.
For security, values such as secrets and keys should not be saved off in static files (such as an ops file). In order to
rectify this, you can use a secret management tool, such as Credhub, to sub in the necessary values to the deployment
manifest.  

Let's assume basic knowledge and understanding of the
[`credhub-interpolate`][credhub interpolate] task described in the [Secrets Handling][secrets handling] section
of the documentation.

For multiple foundations, [`credhub-interpolate`][credhub interpolate] will work the same, but `PREFIX` param will
differ per foundation. This will allow you to keep your `base.yml` the same for each foundation with the same
((placeholder_credential)) reference. Each foundation will require a separate [`credhub-interpolate`][credhub interpolate]
task call with a unique prefix to fill out the missing pieces of the template.

#### Vars Files
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
    - get: pcf-automation-image
      params:
        unpack: true
    - get: pcf-automation-tasks
      params:
        unpack: true
    - get: configuration
    - get: variable
  - task: configure-product
    image: pcf-automation-image
    file: pcf-automation-tasks/tasks/configure-product.yml
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
