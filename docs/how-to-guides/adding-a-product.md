# Extending a pipeline to install a product

This how-to-guide will teach you how to add a product to an existing pipeline.
This includes downloading the product from Tanzu Network,
extracting configuration,
and installing the configured product.

## Prerequisites

1. A pipeline, such as one created in [Installing Tanzu Operations Manager](./installing-opsman.md)
   or [Upgrading an existing Tanzu Operations Manager](./upgrade-existing-opsman.md).
2. A fully configured Tanzu Operations Manager and Director. See [Deploying the Director](./creating-a-director-config-file.md).
3. The Platform Automation Toolkit Docker Image [imported and ready to run](./running-commands-locally.md).
4. A glob pattern uniquely matching one product file on Tanzu Network.

### Assumptions about your existing pipeline

This guide assumes you're working
from one of the pipelines created in previous guides,
but you don't have to have exactly that pipeline.
If your pipeline is different, though,
you may run into trouble with some of our assumptions.

We assume:

- Resource declarations for `config` and `platform-automation`.
- A pivnet token stored in CredHub as a credential named `pivnet_token`.
- A previous job responsible for deploying the director
  called `apply-director-changes`.
- You have created an `env.yml` from the [Configuring Env](./configuring-env.md)
  how-to guide. This file exists in the `configuration` resource.
- You have a `fly` target named `control-plane` with an existing pipeline called `foundation`.
- You have a source control repo that contains the `foundation` pipeline's `pipeline.yml`.

You should be able to use the pipeline YAML in this document with any pipeline,
as long as you make sure the above names match up with what's in your pipeline,
either by changing the example YAML or your pipeline.

## Download, upload, and stage product to Tanzu Operations Manager

For this guide, we're going to add the [VMware Tanzu Application Service for VMs](https://network.pivotal.io/products/elastic-runtime) product.

### Download

Before setting the pipeline, create a config file for [`download-product`](../tasks.md#download-product)
to download Tanzu Application Service from Tanzu Network.

Create a `download-tas.yml`.

{% include ".download-tas-tabs.md" %}

Add and commit this file to the same directory as the previous guides.
This file should be accessible from the `configuration` resource.
```bash
git add download-tas.yml
git commit -m "Add download-tas file for foundation"
git push
``` 

Now that we have a config file,
we can add a new `download-upload-and-stage-tas` job in your `pipeline.yml`.

```yaml hl_lines="3-32"
jobs: # Do not duplicate this if it already exists in your pipeline.yml,
      # just add the following lines to the jobs section
- name: download-upload-and-stage-tas
  serial: true
  plan:
    - aggregate:
      - get: platform-automation-image
        params:
          globs: ["*image*.tgz"]
          unpack: true
      - get: platform-automation-tasks
        params:
          globs: ["*tasks*.zip"]
          unpack: true
      - get: config
    - task: prepare-tasks-with-secrets
      image: platform-automation-image
      file: platform-automation-tasks/tasks/prepare-tasks-with-secrets.yml
      input_mapping:
        tasks: platform-automation-tasks
      output_mapping:
        tasks: platform-automation-tasks
      params:
        CONFIG_PATHS: config
    - task: download-tas
      image: platform-automation-image
      file: platform-automation-tasks/tasks/download-product.yml
      input_mapping:
        config: config
      params:
        CONFIG_FILE: download-tas.yml
      output_mapping:
        downloaded-product: tas-product
        downloaded-stemcell: tas-stemcell
```

Now that we have a runnable job, let's make a commit

```bash
git add pipeline.yml
git commit -m 'download TAS and its stemcell'
```

Then we can set the pipeline

```bash
fly -t control-plane set-pipeline -p foundation -c pipeline.yml
```

If the pipeline sets without errors, run a `git push` of the config.

!!! info "If fly set-pipeline returns an error"
    Fix any and all errors until the pipeline can be set.
    When the pipeline can be set properly, run
    
    ```bash
    git add pipeline.yml
    git commit --amend --no-edit
    git push
    ```

!!! note "Testing Your Pipeline"
    We generally want to try things out right away to see if they're working right.
    However, in this case, if you have a very slow internet connection and/or multiple Concourse workers,
    you might want to hold off until we've got the job doing more,
    so that if it works, you don't have to wait for the download again.

### Upload and Stage
We have a product downloaded and (potentially) cached on a Concourse worker.
The next step is to upload and stage that product to Tanzu Operations Manager.

```yaml hl_lines="32-45"
jobs:
- name: download-upload-and-stage-tas
  serial: true
  plan:
    - aggregate:
      - get: platform-automation-image
        params:
          globs: ["*image*.tgz"]
          unpack: true
      - get: platform-automation-tasks
        params:
          globs: ["*tasks*.zip"]
          unpack: true
      - get: config
    - task: prepare-tasks-with-secrets
      image: platform-automation-image
      file: platform-automation-tasks/tasks/prepare-tasks-with-secrets.yml
      input_mapping:
        tasks: platform-automation-tasks
      output_mapping:
        tasks: platform-automation-tasks
      params:
        CONFIG_PATHS: config
    - task: download-tas
      image: platform-automation-image
      file: platform-automation-tasks/tasks/download-product.yml
      input_mapping:
        config: config
      params:
        CONFIG_FILE: download-tas.yml
      output_mapping:
        downloaded-product: tas-product
        downloaded-stemcell: tas-stemcell
    - task: upload-tas-stemcell
      image: platform-automation-image
      file: platform-automation-tasks/tasks/upload-stemcell.yml
      input_mapping:
        env: config
        stemcell: tas-stemcell
      params:
        ENV_FILE: env.yml
    - task: upload-and-stage-tas
      image: platform-automation-image
      file: platform-automation-tasks/tasks/upload-and-stage-product.yml
      input_mapping:
        product: tas-product
        env: config
```

Then we can re-set the pipeline

```bash
fly -t control-plane set-pipeline -p foundation -c pipeline.yml
```

and if all is well, make a commit and push

```bash
git add pipeline.yml
git commit -m 'upload tas and stemcell to Ops Manager'
git push
```

## Product configuration

Before automating the configuration and install of the product,
we need a config file.
The simplest way is to choose your config options in the Tanzu Operations Manager UI,
then pull its resulting configuration.

<p class="note">
<span class="note__title">Note</span>
Advanced Tile Config Option:
For an alternative that generates the configuration
from the product file, using ops files to select options,
see <a href="./adding-a-product.md#config-template">Config template</a>
</p>

### Pulling Configuration from Tanzu Operations Manager

Configure the product _manually_ according to the product's install instructions.
This guide installs [Tanzu Application Service](https://docs.vmware.com/en/VMware-Tanzu-Application-Service/5.0/tas-for-vms/vsphere-nsx-t.html).
You can find installation instructions in [VMware Tanzu Docs](https://docs.vmware.com/en/VMware-Tanzu-Application-Service/5.0/tas-for-vms/toc-installing-index.html).

Once the product is fully configured, apply changes in the Tanzu Operations Manager UI,
and then continue this guide.

<p class="note important">
<span class="note__title">Important</span>
If you do not <b>Apply Changes</b>:
Tanzu Operations Manager cannot generate credentials for you
until you have applied changes (at least once).
You can still go through this process without an initial applying changes,
but you will be unable to use <code>om staged-config</code> with <code>--include-credentials</code>,
and may have an incomplete configuration at the end of this process.</p>

[`om`](https://github.com/pivotal-cf/om) has a command called [staged-config](../tasks.md#staged-config),
which is used to extract staged product
configuration from the Tanzu Operations Manager UI.
`om` requires a `env.yml`, which we already used in the `upload-and-stage` task.

Most products will contain the following top-level keys:

- network-properties
- product-properties
- resource-config

The command can be run directly using Docker.
We'll need to download the image to our local workstation, import it into Docker,
and then run `staged-config` for the [Tanzu Application Service](https://docs.vmware.com/en/VMware-Tanzu-Application-Service/5.0/tas-for-vms/vsphere-nsx-t.html) product.
For more information, see [Running commands locally](./running-commands-locally.md).

After you download the image from [Tanzu Network](https://network.pivotal.io/products/platform-automation/)
you need the product name recognized by Tanzu Operations Manager.
This can be found using `om`, but first, import the image.

```bash
export ENV_FILE=env.yml
docker import ${PLATFORM_AUTOMATION_IMAGE_TGZ} platform-automation-image
```

Then, we can run `om staged-products` to find the name of the product in Tanzu Operations Manager.
```bash
docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
om --env ${ENV_FILE} staged-products
```

The result should be a table that looks like the following
```text
+---------------------------+-----------------+
|           NAME            |     VERSION     |
+---------------------------+-----------------+
| cf                        | <VERSION>       |
| p-bosh                    | <VERSION>       |
+---------------------------+-----------------+
```

`p-bosh` is the name of the director.
As `cf` is the only other product on our Tanzu Operations Manager,
we can safely assume that this is the product name for [Tanzu Application Service](https://network.pivotal.io/products/elastic-runtime).

Using the product name `cf`,
let's extract the current configuration from Tanzu Operations Manager.

```bash
docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
om --env ${ENV_FILE} staged-config --include-credentials --product-name cf > tas-config.yml
```

We have a configuration file for our tile ready to back up! Almost.
There are a few more steps required before we're ready to commit.

#### Parameterizing the config

Look through your `tas-config.yml` for any sensitive values.
These values should be `((parameterized))`
and saved off in a secrets store (in this example, we use CredHub).

You should still be logged into CredHub.
If not, login. Be sure to note the space at the beginning of the line.
This will ensure your valuable secrets are not saved in terminal history.

{% include ".logging-into-credhub.md" %}

The example list of some sensitive values from our `tas-config.yml` are as follows,
note that this is intentionally incomplete.
```yaml
product-properties:
  .properties.cloud_controller.encrypt_key:
    value:
      secret: my-super-secure-secret
  .properties.networking_poe_ssl_certs:
    value:
    - certificate:
        cert_pem: |-
          -----BEGIN CERTIFICATE-----
          my-cert
          -----END CERTIFICATE-----
        private_key_pem: |-
          -----BEGIN RSA PRIVATE KEY-----
          my-private-key
          -----END RSA PRIVATE KEY-----
      name: certificate
```

We'll start with the Cloud Controller encrypt key.
As this is a value that you might wish to rotate at some point,
we're going to store it off as a `password` type into CredHub.

```bash
# note the starting space
 credhub set \
   --name /concourse/your-team-name/cloud_controller_encrypt_key \
   --type password \
   --password my-super-secure-secret
```

To validate that we set this correctly,
we should run.

```bash
# no need for an extra space
credhub get --name /concourse/your-team-name/cloud_controller_encrypt_key
```

and expect an output like
```text
id: <guid>
name: /concourse/your-team-name/cloud_controller_encrypt_key
type: password
value: my-super-secure-secret
version_created_at: "<timestamp>"
```

We are then going to store off the Networking POE certs
as a `certificate` type in CredHub. 
But first, we're going to save off the certificate and private key 
as plain text files to simplify this process.
We named these files `poe-cert.txt` and `poe-private-key.txt`.
There should be no formatting or indentation in these files, only new lines.

```bash
# note the starting space
 credhub set \
   --name /concourse/your-team-name/networking_poe_ssl_certs \
   --type rsa \
   --public poe-cert.txt \
   --private poe-private-key.txt
```

And again, we're going to validate that we set this correctly

```bash
# no need for an extra space
credhub get --name /concourse/your-team-name/networking_poe_ssl_certs
```

and expect and output like

```text
id: <guid>
name: /concourse/your-team-name/networking_poe_ssl_certs
type: rsa
value:
  private_key: |
    -----BEGIN RSA PRIVATE KEY-----
    my-private-key
    -----END RSA PRIVATE KEY-----
  public_key: |
    -----BEGIN CERTIFICATE-----
    my-cert
    -----END CERTIFICATE-----
version_created_at: "<timestamp>"
```

!!! warning "Remove Credentials from Disk" 
    Once we've validated that the certs are set correctly in CredHub, 
    remember to delete `poe-cert.txt` and `poe-private-key.txt` from your working directory.
    This will prevent a potential security leak, 
    or an accidental commit of those credentials.
    
Repeat this process for all sensitive values found in your `tas-config.yml`.

Once completed, we can remove those secrets from `tas-config.yml`
and replace them with `((parameterized-values))`.
The parameterized value name should match the name in CredHub.
For our example, we parameterized the config like:

```yaml
product-properties:
  .properties.cloud_controller.encrypt_key:
    value:
      secret: ((cloud_controller_encrypt_key))
  .properties.networking_poe_ssl_certs:
    value:
    - certificate:
        cert_pem: ((networking_poe_ssl_certs.public_key))
        private_key_pem: ((networking_poe_ssl_certs.private_key))
      name: certificate
```

Once your `tas-config.yml` is parameterized to your liking,
we can finally commit the config file.

```bash
git add tas-config.yml
git commit -m "Add tas-config file for foundation"
git push
```

## Configure and Apply
With the hard part out of the way,
we can now configure the product and apply changes.

First, we need to update the pipeline
to have a configure-product step.

```yaml hl_lines="46-76"
jobs:
- name: download-upload-and-stage-tas
  serial: true
  plan:
    - aggregate:
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
    - task: prepare-tasks-with-secrets
      image: platform-automation-image
      file: platform-automation-tasks/tasks/prepare-tasks-with-secrets.yml
      input_mapping:
        tasks: platform-automation-tasks
      output_mapping:
        tasks: platform-automation-tasks
      params:
        CONFIG_PATHS: config
    - task: download-tas
      image: platform-automation-image
      file: platform-automation-tasks/tasks/download-product.yml
      input_mapping:
        config: config
      params:
        CONFIG_FILE: download-tas.yml
      output_mapping:
        downloaded-product: tas-product
        downloaded-stemcell: tas-stemcell
    - task: upload-tas-stemcell
      image: platform-automation-image
      file: platform-automation-tasks/tasks/upload-stemcell.yml
      input_mapping:
        env: config
        stemcell: tas-stemcell
      params:
        ENV_FILE: env/env.yml
    - task: upload-and-stage-tas
      image: platform-automation-image
      file: platform-automation-tasks/tasks/stage-product.yml
      input_mapping:
        product: tas-product
        env: config
- name: configure-tas
  serial: true
  plan:
    - aggregate:
      - get: platform-automation-image
        passed: [download-upload-and-stage-tas]
        trigger: true
        params:
          globs: ["*image*.tgz"]
          unpack: true
      - get: platform-automation-tasks
        params:
          globs: ["*tasks*.zip"]
          unpack: true
      - get: config
        passed: [download-upload-and-stage-tas]
    - task: prepare-tasks-with-secrets
      image: platform-automation-image
      file: platform-automation-tasks/tasks/prepare-tasks-with-secrets.yml
      input_mapping:
        tasks: platform-automation-tasks
      output_mapping:
        tasks: platform-automation-tasks
      params:
        CONFIG_PATHS: config
    - task: configure-tas
      image: platform-automation-image
      file: platform-automation-tasks/tasks/configure-product.yml
      input_mapping:
        config: config
        env: config
      params:
        CONFIG_FILE: tas-config.yml
```

This new job will configure the TAS product
with the config file we previously created.

Next, we need to add an apply-changes job
so that these changes will be applied by the Tanzu Operations Manager.

```yaml hl_lines="31-56"
- name: configure-tas
  serial: true
  plan:
    - aggregate:
      - get: platform-automation-image
        trigger: true
        params:
          globs: ["*image*.tgz"]
          unpack: true
      - get: platform-automation-tasks
        params:
          globs: ["*tasks*.zip"]
          unpack: true
      - get: config
        passed: [download-upload-and-stage-tas]
    - task: prepare-tasks-with-secrets
      image: platform-automation-image
      file: platform-automation-tasks/tasks/prepare-tasks-with-secrets.yml
      input_mapping:
        tasks: platform-automation-tasks
      output_mapping:
        tasks: platform-automation-tasks
      params:
        CONFIG_PATHS: config
    - task: configure-tas
      image: platform-automation-image
      file: platform-automation-tasks/tasks/configure-product.yml
      input_mapping:
        config: config
        env: config
      params:
        CONFIG_FILE: tas-config.yml
- name: apply-changes
  serial: true
  plan:
    - aggregate:
      - get: platform-automation-image
        params:
          globs: ["*image*.tgz"]
          unpack: true
      - get: platform-automation-tasks
        params:
          globs: ["*tasks*.zip"]
          unpack: true
      - get: config
        passed: [configure-tas]
    - task: prepare-tasks-with-secrets
      image: platform-automation-image
      file: platform-automation-tasks/tasks/prepare-tasks-with-secrets.yml
      input_mapping:
        tasks: platform-automation-tasks
      output_mapping:
        tasks: platform-automation-tasks
      params:
        CONFIG_PATHS: config
    - task: apply-changes
      image: platform-automation-image
      file: platform-automation-tasks/tasks/apply-changes.yml
      input_mapping:
        env: config
```

!!! info "Adding Multiple Products"
    When adding multiple products, you can add the configure jobs as passed constraints
    to the apply-changes job so that they all are applied at once.
    Tanzu Operations Manager will handle any inter-product dependency ordering.
    This will speed up your apply changes
    when compared with running an apply changes for each product separately.
    
    Example:
    `passed: [configure-tas, configure-tas-windows, configure-healthwatch]`


Set the pipeline one final time,
run the job, and see it pass.

```bash
fly -t control-plane set-pipeline -p foundation -c pipeline.yml
```

Commit the final changes to your repository.

```bash
git add pipeline.yml
git commit -m "configure-tas and apply-changes"
git push
```

You have now successfully added a product to your automation pipeline.

## Advanced concepts
### Config template

An alternative to the staged-config workflow
outlined in the how-to guide is `config-template`.

`config-template` is an `om` command that creates a base config file with optional ops files
from a given tile or pivnet slug.

This section will assume [TAS](https://network.pivotal.io/products/elastic-runtime), as in the how-to guide above.

#### Generate the config template directory

```bash
# note the leading space
 export PIVNET_API_TOKEN='your-vmware-tanzu-network-api-token'
```

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

The directory will contain a `product.yml` file.
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
You might consider creating a separate vars file for each of the following cases:

- credentials (These vars can then be persisted separately/securely. See [Using a secrets store to store credentials](../concepts/secrets-handling.md))
- foundation-specific variables when using the same template for multiple foundations

You can use the `--skip-missing` flag when creating your final template
using `om interpolate` to leave such vars to be rendered later.

If you're having trouble figuring out what the values should be,
here are some approaches you can use:

- Look in the template where the variable appears for some additional context of its value.
- Look at the tile's online documentation
- Upload the tile to an Tanzu Operations Manager 
  and visit the tile in the Tanzu Operations Manager UI to see if that provides any hints.
  
    If you are still struggling, inspecting the html of the Tanzu Operations Manager webpage
    can more accurately map the value names to the associated UI element.

<p class="note">
<span class="note__title">Note</span>
When using the Tanzu Operations Manager docs and UI,
be aware that the field names in the UI do not necessarily map directly to property names.</p>

#### Optional Features
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
        <td>contains configuration that can be applied to resource configuration. For example, BOSH VM extensions</td>
    </tr>
</table>

For more information on BOSH VM Extensions, refer to the [Creating a director config file](./creating-a-director-config-file.md#vm-extensions).

To use an ops file, add `-o`
with the path to the ops file you want to use to your `interpolate` command.

So, to enable TCP routing in Tanzu Application Service, you would add `-o features/tcp_routing-enable.yml`.
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
Handle vars that are secret more carefully. See [Using a secrets store to store credentials](../concepts/secrets-handling.md).

You can then dispose of the config template directory.

## Using ops files for multi-foundation

There are two recommended ways to support multiple foundation workflows:
using [secrets management](../concepts/secrets-handling.md#multi-foundation-secrets-handling) or ops files.
This section will explain how to support multiple foundations using ops files.

Starting with an incomplete [Tanzu Application Service](https://network.pivotal.io/products/elastic-runtime) config from **vSphere** as an example:

{% include ".cf-partial-config.md" %}

For a single foundation deploy, leaving values such as
`".cloud_controller.apps_domain"` as-is would work fine. For multiple
foundations, this value will be different per deployed foundation. Other values,
such as `.cloud_controller.encrypt_key` have a secret that
already have a placeholder from `om`. If different foundations have different
load requirements, even the values in `resource-config` can be edited using
[ops files](https://bosh.io/docs/cli-ops-files/).

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
* VMware cannot guarantee the functionality of upgrade scripts in third-party products.

Replicating configuration settings from one product to the same product on a different foundation:

* Because properties and property names can change between patch versions of a product,
  you can only safely apply configuration settings across products if their versions exactly match.

[//]: # ({% with path="../" %})
[//]: # (    {% include ".internal_link_url.md" %})
[//]: # ({% endwith %})
[//]: # ({% include ".external_link_url.md" %})
