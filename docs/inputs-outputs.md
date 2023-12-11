# Task inputs and outputs

##  Inputs

These are the inputs that can be provided to the tasks.
Each task can only take a specific set, indicated under the `inputs` property of the YAML.

### director config

The config director will set the bosh tile (director) on Tanzu Operations Manager.

The `config` input for a director task expects to have a `director.yml` file.
The configuration of the `director.yml` is IAAS specific for some properties -- i.e. networking.

There are two ways to build a director config.

1. Using an already deployed Tanzu Operations Manager, you can extract the config using [staged-director-config](./tasks.md#staged-director-config).
2. Deploying a brand new Tanzu Operations Manager requires more effort for a `director.yml`.
   The configuration of director is variables based on the features enabled.
   For brevity, this `director.yml` is a basic example for vsphere.

---excerpt--- "examples/director-configuration"

The IAAS specific configuration can be found in the Tanzu Operations Manager API documentation.

What follows is a list of properties that can be set in the `director.yml`
and a link to the API documentation explaining any IAAS specific properties.

* `az-configuration` - a list of [availability zones](https://docs.pivotal.io/platform/3-0/opsman-api/#tag/Availability-Zones/paths/~1api~1v0~1staged~1director~1availability_zones/get)
* `network-assignment` - the [network](https://docs.pivotal.io/platform/3-0/opsman-api/#tag/Networks-and-AZs-assignment/paths/~1api~1v0~1staged~1director~1network_and_az/put) the BOSH Director is deployed to
* `networks-configuration` - a list of [named networks](https://docs.pivotal.io/platform/3-0/opsman-api/#tag/Networks/paths/~1api~1v0~1staged~1director~1networks/put)
* `properties-configuration` - [BOSH Director configuration and properties](https://docs.pivotal.io/platform/3-0/opsman-api/#tag/Properties/paths/~1api~1v0~1staged~1director~1properties/get)
    * `director_configuration` - BOSH Director properties
    * `security_configuration` - BOSH Director security properties
    * `syslog_configuration` - configure the syslog sinks for the BOSH Director
* `resource-configuration` - [IAAS VM flavor](https://docs.pivotal.io/platform/3-0/opsman-api/#tag/Job-Resource-Configuration/paths/~1api~1v0~1staged~1products~1{product_guid}~1resources/get) for the BOSH Director
* `vmextensions-configuration` - create/update/delete [VM extensions](https://docs.pivotal.io/platform/3-0/opsman-api/#tag/VM-Extensions)

#### GCP Shared VPC

Support for Shared VPC is done via configuring the `iaas_identifier` path for the [infrastructure subnet]https://docs.vmware.com/en/VMware-Tanzu-Operations-Manager/3.0/vmware-tanzu-ops-manager/gcp-prepare-env-manual.html#create_network,
which includes the host project id, region of the subnet, and the subnet name.

For example:

`[HOST_PROJECT_ID]/[NETWORK]/[SUBNET]/[REGION]`

### download-product-config

The `config` input for a download product task 
can be used with a `download-config.yml` file to download a tile.
The configuration of the `download-config.yml` looks like this:

=== "Tanzu Network"
    ---excerpt--- "examples/download-product-config-pivnet"
=== "S3"
    ---excerpt--- "examples/download-product-config-s3"
=== "GCS"
    ---excerpt--- "examples/download-product-config-gcs"
=== "Azure"
    ---excerpt--- "examples/download-product-config-azure"

### download-stemcell-product-config

The `config` input for a download product task 
can be used with a `download-config.yml` file to download a stemcell.
The configuration of the `download-config.yml` looks like this:

---excerpt--- "examples/download-stemcell-product-config"

### env

The `env` input for a task expects to have a `env.yml` file.
This file contains properties for targeting and logging into the Tanzu Operations Manager API.

=== "basic auth"
    ---excerpt--- "examples/env"
=== "uaa auth"
    ---excerpt--- "examples/env-uaa"

#### Getting the `client-id` and `client-secret`

Tanzu Operations Manager will by preference use Client ID and Client Secret if provided.
To create a Client ID and Client Secret

1. `uaac target https://YOUR_OPSMANAGER/uaa`
1. `uaac token sso get` if using SAML or `uaac token owner get` if using basic auth. Specify the Client ID as `opsman` and leave Client Secret blank.
1. Generate a client ID and secret

```bash
uaac client add -i
Client ID:  NEW_CLIENT_NAME
New client secret:  DESIRED_PASSWORD
Verify new client secret:  DESIRED_PASSWORD
scope (list):  opsman.admin
authorized grant types (list):  client_credentials
authorities (list):  opsman.admin
access token validity (seconds):  43200
refresh token validity (seconds):  43200
redirect uri (list):
autoapprove (list):
signup redirect url (url):
```

### errand config

The `ERRAND_CONFIG_FILE` input for the [`apply-changes`](./tasks.md#apply-changes) task.
This file contains properties for enabling and disabling errands
for a particular run of `apply-changes`.

To retrieve the default configuration of your product's errands,
[`staged-config`](./tasks.md#staged-config) can be used.

The expected format for this errand config is as follows:

  ```yaml
  errands:
    sample-product-1:
      run_post_deploy:
        smoke_tests: default
        push-app: false
      run_pre_delete:
        smoke_tests: true
    sample-product-2:
      run_post_deploy:
        smoke_tests: default
  ```

### installation

The file contains the information to restore an Tanzu Operations Manager VM.
The `installation` input for a opsman VM task expects to have a `installation.zip` file.

This file can be exported from an Tanzu Operations Manager VM using the [export-installation](./tasks.md#export-installation).
This file can be imported to an Tanzu Operations Manager VM using the [import-installation](./tasks.md#import-installation).

<p class="note important">
<span class="note__title">Important</span>
This file cannot be manually created. It is a file that must be generated via the export function of Tanzu Operations Manager.</p>

### Tanzu Operations Manager config
The config for an Tanzu Operations Manager described IAAS specific information for creating the VM -- i.e. VM flavor (size), IP addresses

The `config` input for opsman task expects to have a `opsman.yml` file.
The configuration of the `opsman.yml` is IAAS specific.

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
=== "Additional Settings"
    ---excerpt--- "examples/opsman-settings"

Specific advice and features for the different IaaSs are documented below

#### AWS

These required properties are adapted from the instructions outlined in
[Requirements and prerequisites for Tanzu Operations Manager on AWS](https://docs.vmware.com/en/VMware-Tanzu-Operations-Manager/3.0/vmware-tanzu-ops-manager/install-aws.html).

{% include '.ip-addresses.md' %}

<p class="note important">
<span class="note__title">Important</span>
Using <code>instance_profile</code> to avoid secrets:
For authentication you must either set <code>use_instance_profile: true</code>
or provide a <code>secret_key_id</code> and <code>secret_access_key</code>.
You must remove key information if you're using an instance profile.
Using an instance profile allows you to avoid interpolation,
as this file then contains no secrets.</p>

#### Azure

The required properties are adapted from the instructions outlined in
[Requirements and prerequisites for Tanzu Operations Manager on Azure](https://docs.vmware.com/en/VMware-Tanzu-Operations-Manager/3.0/vmware-tanzu-ops-manager/install-azure.html).

{% include '.ip-addresses.md' %}

#### GCP

The required properties are adapted from the instructions outlined in
[Requirements and prerequisites for Tanzu Operations Manager on GCP](https://docs.vmware.com/en/VMware-Tanzu-Operations-Manager/3.0/vmware-tanzu-ops-manager/install-gcp.html.)

{% include '.ip-addresses.md' %}

<p class="note important">
<span class="note__title">Important</span>
Using a service account name to Avoid Secrets:
For authentication either <code>gcp_service_account</code> or <code>gcp_service_account_name</code> is required.
You must remove the one you are not using
note that using <code>gcp_service_account_name</code> allows you to avoid interpolation,
as this file then contains no secrets.</p>

Support for Shared VPC is done using 

[configuring the `vpc_subnet` path](https://cloud.google.com/vpc/docs/provisioning-shared-vpc#creating_an_instance_in_a_shared_subnet)
to include the host project id, region of the subnet, and the subnet name.

For example:

`projects/[HOST_PROJECT_ID]/regions/[REGION]/subnetworks/[SUBNET]`

#### Openstack

The required properties are adapted from the instructions outlined in
[Installing and configuring Tanzu Operations Manager on OpenStack](https://docs.vmware.com/en/VMware-Tanzu-Operations-Manager/3.0/vmware-tanzu-ops-manager/openstack-index.html)

{% include '.ip-addresses.md' %}

#### vSphere

The required properties are adapted from the instructions outlined in
[Installing and configuring Tanzu Operations Manager on vSphere](https://docs.vmware.com/en/VMware-Tanzu-Operations-Manager/3.0/vmware-tanzu-ops-manager/vsphere-index.html)

### opsman image

This file is an [artifact from Tanzu Network](https://network.pivotal.io/products/ops-manager),
which contains the VM image for a specific IaaS.
For vsphere and openstack, it's a full disk image.
For AWS, GCP, and Azure, it's a YAML file listing the location
of images that are already available on the IaaS.

These are examples to download the image artifact for each IaaS
using the [download-product](./tasks.md#download-product) task.

#### opsman.yml

{% include "how-to-guides/.opsman-config-tabs.md" %}

The `p-automator` CLI includes the ability to extract the Tanzu Operations Manager VM configuration (GCP, AWS, Azure, and VSphere).
This works for Tanzu Operations Managers that are already running and useful when [migrating to automation](./how-to-guides/upgrade-existing-opsman.md).

Usage:

1. Get the Platform Automation Toolkit image from Tanzu Network.
2. Import that image into `docker` to run the `p-automation` [locally](./how-to-guides/running-commands-locally.md).
3. Create a [state file](./inputs-outputs.md#state]) that represents your current VM and IAAS.
4. Invoke the `p-automator` CLI to get the configuration.

For example, on AWS with an access key and secret key:

```bash
docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
p-automator export-opsman-config \
--state-file=state.yml \
--aws-region=us-west-1 \
--aws-secret-access-key some-secret-key \
--aws-access-key-id some-access-key
```

The outputted `opsman.yml` contains the information needed for Platform Automation Toolkit to manage the Tanzu Operations Manager VM.

#### download-product task

```yaml
- task: download-opsman-image
  image: platform-automation-image
  file: platform-automation-tasks/tasks/download-product.yml
  params:
    CONFIG_FILE: opsman.yml
```

### product

The `product` input requires a single tile file (`.pivotal`) as downloaded from Tanzu Network.

Here's an example of how to pull the Tanzu Application Service tile
using the [download-product](./tasks.md#download-product) task.

#### product.yml

```yaml
---
pivnet-api-token: token
pivnet-file-glob: "cf-*.pivotal"
pivnet-product-slug: elastic-runtime
product-version-regex: ^2\.6\..*$
```

#### download-product task

```yaml
- task: download-stemcell
  image: platform-automation-image
  file: platform-automation-tasks/tasks/download-product.yml
  params:
    CONFIG_FILE: product.yml
```

<p class="note important">
<span class="note__title">Important</span>
This file cannot be manually created. This file must retrieved from Tanzu Network.</p>
    
### product config

There are two ways to build a product config.

1. Using an already deployed product (tile), you can extract the config using [staged-config](./tasks.md#staged-config).
1. Use an example and fill in the values based on the meta information from the tile.
For brevity, this `product.yml` is a basic example for `healthwatch`.

---excerpt--- "examples/product-configuration"

The following is a list of properties that can be set in the `product.yml`
and a link to the API documentation explaining the properties.

* `product-properties` - Tanzu Operations Manager [tile properties](https://docs.pivotal.io/platform/3-0/opsman-api/#tag/Properties/paths/~1api~1v0~1staged~1products~1{product_guid}~1properties/get)
* `network-properties` - a list Tanzu Operations Manager [named networks](https://docs.pivotal.io/platform/3-0/opsman-api/#tag/Networks-and-AZs-assignment/paths/~1api~1v0~1staged~1products~1:product_guid~1networks_and_azs/put)
* `resource-config` - for the jobs of the Tanzu Operations Manager [tile](https://docs.pivotal.io/platform/3-0/opsman-api/#tag/Networks-and-AZs-assignment/paths/~1api~1v0~1staged~1products~1:product_guid~1networks_and_azs/put)

### state

This file contains that meta-information needed to manage the Tanzu Operations Manager VM.
The `state` input for a opsman VM task expects to have a `state.yml` file.

The `state.yml` file contains two properties:

1. `iaas` is the IAAS the Tanzu Operations Manager VM is hosted on. (`gcp`, `vsphere`, `aws`, `azure`, `openstack`)
2. `vm_id` is the VM unique identifier for the VM. For some IAAS, the VM ID is the VM name.

Different IaaS uniquely identify VMs differently;
here are examples for what this file should look like,
depending on your IAAS:

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

### stemcell
This `stemcell` input requires the stemcell tarball (`.tgz`) as downloaded from Tanzu Network.
It must be in the original filename as that is used by Tanzu Operations Manager to parse metadata.
The filename could look like `bosh-stemcell-621.76-vsphere-esxi-ubuntu-xenial-go_agent.tgz`.

<p class="note important">
<span class="note__title">Important</span>
This file cannot be manually created. This file must retrieved from Tanzu Network.</p>

Here's an example of how to pull the vSphere stemcell
using the [download-product](./tasks.md#download-product) task.

#### stemcell.yml

=== "AWS"
    ```yaml
    ---
    pivnet-api-token: token
    pivnet-file-glob: "bosh-stemcell-*-aws*.tgz"
    pivnet-product-slug: stemcells-ubuntu-xenial
    product-version-regex: ^170\..*$
    ```

=== "Azure"
    ```yaml
    ---
    pivnet-api-token: token
    pivnet-file-glob: "bosh-stemcell-*-azure*.tgz"
    pivnet-product-slug: stemcells-ubuntu-xenial
    product-version-regex: ^170\..*$
    ```

=== "GCP"
    ```yaml
    ---
    pivnet-api-token: token
    pivnet-file-glob: "bosh-stemcell-*-google*.tgz"
    pivnet-product-slug: stemcells-ubuntu-xenial
    product-version-regex: ^170\..*$
    ```

=== "OpenStack"
    ```yaml
    ---
    pivnet-api-token: token
    pivnet-file-glob: "bosh-stemcell-*-openstack*.tgz"
    pivnet-product-slug: stemcells-ubuntu-xenial
    product-version-regex: ^170\..*$
    ```

=== "vSphere"
    ```yaml
    ---
    pivnet-api-token: token
    pivnet-file-glob: "bosh-stemcell-*-vsphere*.tgz"
    pivnet-product-slug: stemcells-ubuntu-xenial
    product-version-regex: ^170\..*$
    ```


#### download-product task

```yaml
- task: download-stemcell
  image: platform-automation-image
  file: platform-automation-tasks/tasks/download-product.yml
  params:
    CONFIG_FILE: stemcell.yml
```

#### assign-stemcell-task

This artifact is an output of [`download-product`](./tasks.md#download-product)
located in the `assign-stemcell-config` output directory.

This file should resemble the following:
```yaml
product: cf
stemcell: "97.190"
```

### telemetry

The `config` input for the [collect-telemetry](./tasks.md#collect-telemetry) task
can be used with a `telemetry.yml` file to collect data for VMware
so they can learn and measure results
in order to put customer experience at the forefront of their product decisions.
The configuration of the `telemetry.yml` looks like this:

---excerpt--- "examples/telemetry"

[//]: # ({% include ".internal_link_url.md" %})
[//]: # ({% include ".external_link_url.md" %})
