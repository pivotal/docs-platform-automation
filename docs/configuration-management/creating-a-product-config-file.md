
Extracting a product configuration file, an externalized config that lives outside of OpsManager, can make it easier to manage multiple foundations as well as help with:

- traceability
- avoiding configuration drift
- configuration promotion

## Prerequisites

To extract the configuration for a product, you will first need to do the following:

1. Upload and stage your desired product(s) to a fully deployed OpsManager.
For example, let's use [PAS][PAS] on Vsphere
1. Configure your product _manually_ according to the product's
[install instructions][pas-install-vsphere].

## Extracting Product Configuration

[om] has a command called [staged-config], which is used to extract staged product
configuration present in the OpsManager UI of the targeted foundation.

Sample usage, using `om` directly and assuming the [PAS][PAS] product:  
`om --env env.yml staged-config --include-placeholders --product-name cf > tile-config.yml`  

Most products will contain the following high level keys:

- network-properties
- product-properties
- resource-config

You can check the file in to your VCS.

For convenience, Platform Automation provides you with two ways to use the
`om staged-config` command. The command can be run as a [task][staged-config]
inside of your pipeline. As an example of how to invoke this for the [PAS][PAS] product
in your pipeline.yml(resources not listed):
```
jobs:
- name: staged-pas-config
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
  - task: staged-config
    image: platform-automation-image
    file: platform-automation-tasks/tasks/staged-config.yml
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
configuration of your product, and put it into a `generated-config` folder in the concourse job. The `put` in
concourse allows you to persist this config outside the concourse container.

Alternatively, this can be run external to concourse by using docker. An example
of how to do this using on the linux/mac command line:

{% include ".docker-import-tile.md" %}

## Using Ops Files for Multi-Foundation

`--include-placeholders` in the `om` command is a vital first step to externalizing
your configuration for multiple foundations. This will search the OpsManager product
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

Upgrading products to new patch versions:

* Configuration settings should not differ between successive patch versions within the same minor version line.
    Underlying properties or property names may change,
    but the tile's upgrade process automatically translates properties to the new fields and values.
* Pivotal cannot guarantee the functionality of upgrade scripts in third-party PCF product tiles.

Replicating configuration settings from one product tile to the same product tile on a different foundation:

* Because properties and property names can change between patch versions of a product,
  you can only safely apply configuration settings across product tiles if their versions exactly match.




{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
