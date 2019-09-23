---
title: Input Reference
---

##  Inputs
These are the inputs that can be provided to the tasks.
Each task can only take a specific set, indicated under the `inputs` property of the YAML.

### env

The `env` input for a task expects to have a `env.yml` file.
This file contains properties for targeting and logging into the Ops Manager API.

#### basic authentication
{% code_snippet 'examples', 'env' %}

#### uaa authentication
{% code_snippet 'examples', 'env-uaa' %}


##### Getting the `client-id` and `client-secret`

Ops Manager will by preference use Client ID and Client Secret if provided.
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

### Ops Manager config
The config for an Ops Manager described IAAS specific information for creating the VM -- i.e. VM flavor (size), IP addresses

The `config` input for opsman task expects to have a `opsman.yml` file.
The configuration of the `opsman.yml` is IAAS specific.

Specific examples for each IaaS are as follows:

#### AWS
These required properties are adapted from the instructions outlined in
[Launching an Ops Manager Director Instance on AWS][pivotalcf-aws]

{% code_snippet 'examples', 'aws-configuration' %}
{% include '.ip-addresses.md' %}

!!! info "Using instance_profile to Avoid Secrets"
    For authentication you must either set `use_instance_profile: true`
    or provide a `secret_key_id` and `secret_access_key`.
    You must remove key information if you're using an instance profile.
    Using an instance profile allows you to avoid interpolation,
    as this file then contains no secrets.


#### Azure
These required properties are adapted from the instructions outlined in
[Launching an Ops Manager Director Instance on Azure][pivotalcf-azure]

{% code_snippet 'examples', 'azure-configuration' %}
{% include '.ip-addresses.md' %}

#### GCP
These required properties are adapted from the instructions outlined in
[Launching an Ops Manager Director Instance on GCP][pivotalcf-gcp]

{% code_snippet 'examples', 'gcp-configuration' %}
{% include '.ip-addresses.md' %}

!!! info "Using a Service Account Name to Avoid Secrets"
    For authentication either `gcp_service_account` or `gcp_service_account_name` is required.
    You must remove the one you are not using
    note that using `gcp_service_account_name` allows you to avoid interpolation,
    as this file then contains no secrets.

Support for Shared VPC is done via
[configuring the `vpc_subnet` path][gcp-shared-vpc]
to include the host project id, region of the subnet, and the subnet name.

For example:

`projects/[HOST_PROJECT_ID]/regions/[REGION]/subnetworks/[SUBNET]`

#### Openstack

These required properties are adapted from the instructions outlined in
[Launching an Ops Manager Director Instance on Openstack][pivotalcf-openstack]

{% code_snippet 'examples', 'openstack-configuration' %}
{% include '.ip-addresses.md' %}

#### vSphere

These required properties are adapted from the instructions outlined in
[Deploying BOSH and Ops Manager to vSphere][pivotalcf-vsphere]

{% code_snippet 'examples', 'vsphere-configuration' %}

### director config

The config director will set the bosh tile (director) on Ops Manager.

The `config` input for a director task expects to have a `director.yml` file.
The configuration of the `director.yml` is IAAS specific for some properties -- i.e. networking.

There are two ways to build a director config.

1. Using an already deployed Ops Manager, you can extract the config using [staged-director-config].
2. Deploying a brand new Ops Manager requires more effort for a `director.yml`.
   The configuration of director is variables based on the features enabled.
   For brevity, this `director.yml` is a basic example for vsphere.

{% code_snippet 'examples', 'director-configuration' %}

The IAAS specific configuration can be found in the Ops Manager API documentation.

Included below is a list of properties that can be set in the `director.yml`
and a link to the API documentation explaining any IAAS specific properties.

* `az-configuration` - a list of availability zones [Ops Manager API][opsman-api-azs]
* `network-assignment` - the network the bosh director is deployed to [Ops Manager API][opsman-api-network-az-assignment]
* `networks-configuration` - a list of named networks [Ops Manager API][opsman-api-networks]
* `properties-configuration`
    * `iaas_configuration` - configuration for the bosh IAAS CPI [Ops Manager API][opsman-api-director-properties]
    * `director_configuration` - properties for the bosh director [Ops Manager API][opsman-api-director-properties]
    * `security_configuration` - security properties for the bosh director [Ops Manager API][opsman-api-director-properties]
    * `syslog_configuration` - configure the syslog sinks for the bosh director [Ops Manager API][opsman-api-director-properties]
* `resource-configuration` - IAAS VM flavor for the bosh director [Ops Manager API][opsman-api-resource-config]
* `vmextensions-configuration` - create/update/delete vm extensions [Ops Manager API][opsman-api-vm-extension]

#### GCP Shared VPC

Support for Shared VPC is done via configuring the `iaas_identifier` path for the [infrastructure subnet](https://docs.pivotal.io/pivotalcf/customizing/gcp-prepare-env.html#create_network),
which includes the host project id, region of the subnet, and the subnet name.

For example:

`[HOST_PROJECT_ID]/[NETWORK]/[SUBNET]/[REGION]`

### product config

There are two ways to build a product config.

1. Using an already deployed product (tile), you can extract the config using [staged-config].
1. Use an example and fill in the values based on the meta information from the tile.
For brevity, this `product.yml` is a basic example for `healthwatch`.

{% code_snippet 'examples', 'product-configuration' %}

Included below is a list of properties that can be set in the `product.yml`
and a link to the API documentation explaining the properties.

* `product-properties` - properties for the tile [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#updating-a-selector-property)
* `network-properties` - a list of named networks to deploy the VMs to [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#configuring-networks-and-azs)
* `resource-config` - for the jobs of the tile [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#configuring-resources-for-a-job)

### state

This file contains that meta-information needed to manage the Ops Manager VM.
The `state` input for a opsman VM task expects to have a `state.yml` file.

The `state.yml` file contains two properties:

1. `iaas` is the IAAS the ops manager vm is hosted on. (`gcp`, `vsphere`, `aws`, `azure`, `openstack`)
2. `vm_id` is the VM unique identifier for the VM. For some IAAS, the vm ID is the VM name.

Different IaaS uniquely identify VMs differently;
here are examples for what this file should look like,
depending on your IAAS:

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

### opsman image

This file is an [artifact from Pivnet](https://network.pivotal.io/products/ops-manager),
which contains the VM image for a specific IaaS.
For vsphere and openstack, it's a full disk image.
For AWS, GCP, and Azure, it's a YAML file listing the location
of images that are already available on the IaaS.

Here's an example of how to pull the AWS image resource
using the [download-product][download-product] task.

#### opsman.yml

```yaml
---
pivnet-api-token: token
pivnet-file-glob: "ops-manager-aws*.yml"
pivnet-product-slug: ops-manager
product-version-regex: ^.*\..*\..*$
```

#### download-product task

```yaml
- task: download-opsman-image
  image: platform-automation-image
  file: platform-automation-tasks/tasks/download-product.yml
  params:
    CONFIG_FILE: opsman.yml
```

### installation

The file contains the information to restore an Ops Manager VM.
The `installation` input for a opsman VM task expects to have a `installation.zip` file.

This file can be exported from an Ops Manager VM using the [export-installation][export-installation].
This file can be imported to an Ops Manager VM using the [import-installation][import-installation].

!!! warning
    This file cannot be manually created. It is a file that must be generated via the export function of Ops Manager.

### stemcell
This `stemcell` input requires the stemcell tarball (`.tgz`) as downloaded from Pivnet.
It must be in the original filename as that is used by Ops Manager to parse metadata.
The filename could look like `bosh-stemcell-3541.48-vsphere-esxi-ubuntu-trusty-go_agent.tgz`.

!!! warning
    This file cannot be manually created. It is a file that must retrieved from Pivnet.

Here's an example of how to pull the vSphere stemcell
using the [download-product][download-product] task.

#### stemcell.yml

```yaml
---
pivnet-api-token: token
pivnet-file-glob: "bosh-stemcell-*-vsphere*.tgz"
pivnet-product-slug: stemcells-ubuntu-xenial
product-version-regex: ^.*\..*$
```

#### download-product task

```yaml
- task: download-stemcell
  image: platform-automation-image
  file: platform-automation-tasks/tasks/download-product.yml
  params:
    CONFIG_FILE: stemcell.yml
```

### product

The `product` input requires a single tile file (`.pivotal`) as downloaded from Pivnet.

Here's an example of how to pull the Pivotal Application Service tile
using the [download-product][download-product] task.

#### product.yml

```yaml
---
pivnet-api-token: token
pivnet-file-glob: "cf-*.pivotal"
pivnet-product-slug: elastic-runtime
product-version-regex: ^.*\..*.*$
```

#### download-product task

```yaml
- task: download-stemcell
  image: platform-automation-image
  file: platform-automation-tasks/tasks/download-product.yml
  params:
    CONFIG_FILE: product.yml
```

!!! warning
    This file cannot be manually created. It is a file that must retrieved from Pivnet.

### download-product-config

The `config` input for a download product task 
can be used with a `download-config.yml` file to download a tile.
The configuration of the `download-config.yml` looks like this:

{% code_snippet 'examples', 'download-product-config' %}

### download-stemcell-product-config

The `config` input for a download product task 
can be used with a `download-config.yml` file to download a stemcell.
The configuration of the `download-config.yml` looks like this:

{% code_snippet 'examples', 'download-stemcell-product-config' %}

### telemetry

The `config` input for the [collect-telemetry][collect-telemetry] task 
can be used with a `telemetry.yml` file to collect data for Pivotal
so they can learn and measure results 
in order to put customer experience at the forefront of their product decisions.
The configuration of the `telemetry.yml` looks like this:

{% code_snippet 'examples', 'telemetry' %}

{% include ".internal_link_url.md" %}
{% include ".external_link_url.md" %}
