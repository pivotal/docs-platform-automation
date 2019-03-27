
Extracting a product configuration file, an externalized config that lives outside of OpsManager, can make it easier to manage multiple foundations as well as help with:

- traceability
- avoiding configuration drift
- configuration promotion


## From Pivnet

A configuration file can be generated from the tile metadata directly from Pivotal Network.

### Prerequisites
1. A token for the [Pivotal Network API](https://network.pivotal.io/docs/api#how-to-authenticate) is required.
1. You'll need the Platform Automation Docker Image [imported and ready to run][running-commands-locally].
1. For products that have multiple `.pivotal` files, you'll need a glob pattern uniquely matching one of them.

### Workflow

#### Generate the Config Template Directory

```bash
export PIVNET_API_TOKEN='your-pivotal-network-api-token'

```
(Alternatively, you can write the above to a file and `source` it to avoid credentials in your bash history.)

```bash
docker run -it -v $HOME/configs:/configs platform-automation-image \
om config-template \
  --output-directory /configs/ \
  --pivnet-api-token "${PIVNET_API_TOKEN}" \
  --pivnet-product-slug elastic-runtime \
  --product-version '2.5.0' \
  --product-file-glob 'cf*.pivotal' # Only necessary if the product has multiple .pivotal files
```

This will create or update a directory at `$HOME/configs/cf/2.5.0/`.

`cd` into the directory to get started creating your config.

#### Interpolate a Config

The directory will contain a product.yml file.
This is the template for the product configuration you're about to build.
Open it in an editor of your choice.
Get familiar with what's in there.
The values will be variables intended to be interpolated from other sources,
designated with the`(())` syntax.

You can find the value for any property with a default in the `product-default-vars.yml` file.
This file serves as a good example of a variable source.
You'll need to create a vars file of your own for variables without default values.
For the base template, you can get a list of required variables by running
```bash
docker run -it -v $HOME/configs:/configs platform-automation-image \
om interpolate \
  --config product.yml \
  -l product-default-vars.yml \
  -l resource-vars.yml \
  -l errand-vars.yml
```

Put all those vars in a file and give them the appropriate values.
Once you've included all the variables,
the output will be the finished template.
For the rest of this guide,
we will refer to these vars as `required-vars.yml`.

There may be situations that call for splitting your vars across multiple files.
This can be useful if there are vars that need to be interpolated when you apply the configuration,
rather than when you create the final template.
You might consider creating a seperate vars file for each of the following cases:

- credentials (these vars can then be [persisted separately/securely][secrets-handling])
- foundation-specific variables when using the same template for multiple foundations

You can use the `--skip-missing` flag when creating your final template
using `om interpolate` to leave such vars to be rendered later.

If you're having trouble figuring out what the values should be,
here are some approaches you can use:

- Look in the template where the variable appears for some additional context of its value.
- Look at the tile's online documentation
- Upload the tile to an Ops Manager and visit the tile in the Ops Manager UI to see if that provides any hints.

!!! info "When Using The Ops Manager Docs and UI"
    Be aware that the field names in the UI do not necessarily map directly to property names.

##### Optional Features
The above process will get you a default installation,
with no optional features or variables,
that is entirely deployed in a single Availability Zone (AZ).

In order to provide non-required variables,
use multiple AZs,
or make non-default selections for some options,
you'll need to use some of the ops files in one of the following four directories:

<table>
    <tr>
        <td>features</td>
        <td>allow the enabling of selectors for a product. For example, enabling/disabling of an s3 bucket</td>
    </tr>
    <tr>
        <td>network</td>
        <td>contains options for enabling 2-3 availability zones for network configuration</td>
    </tr>
    <tr>
        <td>optional</td>
        <td>contains optional properties without defaults. For optional values that can be provided more than once, there's an ops file for each param count </td>
    </tr>
    <tr>
        <td>resource</td>
        <td>contains configuration that can be applied to resource configuration. For example, BOSH vm extensions</td>
    </tr>
</table>

To use an ops file, add `-o`
with the path to the ops file you want to use to your `interpolate` command.

So, to enable TCP routing in PAS, you would add `-o features/tcp_routing-enable.yml`.
For the rest of this guide, the vars for this feature
are referred to as `feature-vars.yml`.
If you run your complete command, you should again get a list of any newly-required variables.

```bash
docker run -it -v $HOME/configs:/configs platform-automation-image \
om interpolate \
  --config product.yml \
  -l product-default-vars.yml \
  -l resource-vars.yml \
  -l required-vars.yml \
  -o features/tcp_routing-enable.yml \
  -l feature-vars.yml \
  -l errand-vars.yml
```

#### Finalize Your Configuration

Once you've selected your ops files and created your vars files,
decide which vars you want in the template
and which you want to have interpolated later.

Create a final template and write it to a file,
using only the vars you want to in the template,
and using `--skip-missing` to allow the rest to remain as variables.

```bash
docker run -it -v $HOME/configs:/configs platform-automation-image \
om interpolate \
  --config product.yml \
  -l product-default-vars.yml \
  -l resource-vars.yml \
  -l required-vars.yml \
  -o features/tcp_routing-enable.yml \
  -l feature-vars.yml \
  -l errand-vars.yml \
  --skip-missing \
  > pas-config-template.yml
```

You can check-in the resulting configuration to a git repo.
For vars that do not include credentials, you can check those vars files in, as well.
Handle vars that are secret [more carefully][secrets-handling].

You can then dispose of the config template directory.

## From A Staged Product

A configuration can be generated from a staged product on an already existing OpsManager.

### Prerequisites

To extract the configuration for a product, you will first need to do the following:

1. Upload and stage your desired product(s) to a fully deployed OpsManager.
For example, let's use [PAS][PAS] on Vsphere
1. Configure your product _manually_ according to the product's
[install instructions][pas-install-vsphere].

### Workflow

[om] has a command called [staged-config], which is used to extract staged product
configuration present in the OpsManager UI of the targeted foundation.

Sample usage, using `om` directly and assuming the [PAS][PAS] product:  
`om --env env.yml staged-config --include-placeholders --product-name cf > tile-config.yml`  

Most products will contain the following high level keys:

- network-properties
- product-properties
- resource-config

You can check the file in to git.

For convenience, Platform Automation provides you with two ways to use the
`om staged-config` command. The command can be run as a [task][staged-config]
inside of your pipeline. As an example of how to invoke this for the [PAS][PAS] product
in your pipeline.yml(resources not listed):
```yaml
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
This task will connect to the OpsManager defined in your [`env.yml`][generating-env-file], download the current staged
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
