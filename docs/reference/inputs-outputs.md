---
title: Input Reference
owner: PCF Platform Automation
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

### auth

There are two different authentication methods that Ops Manager supports.

#### basic authentication

This method of authentication configuration uses a specified username and password.

See the task for the [`configure-authentication`][configure-authentication] for details.

{% code_snippet 'examples', 'auth-configuration' %}

!!! info
    basic authentication supports both <a href="#basic-authentication">basic env</a> and <a href="#uaa-authentication">uaa env</a> formats

#### ldap authentication

This method of authentication configuration depends on a LDAP service
to provide user information and authentication.

This config file is used as the `config` input in the
[`configure-ldap-authentication`][configure-ldap-authentication] task.

By default, the [`configure-ldap-authentication`][configure-ldap-authentication] task
will create an admin client for use with the BOSH Director.
If you wish to prevent this, add `skip-bosh-admin-client-creation: true` to the config file.

{% code_snippet 'examples', 'ldap-auth-configuration' %}

!!! info
    ldap authentication requires the <a href="#uaa-authentication">uaa env</a> format

The `ldap-configuration` properties configures Ops Manager's usage of an LDAP provider.
The [Ops Manager API Docs][opsman-api-ldap] have more information
about the particular keys used in this configuration.

#### saml authentication

This method of authentication configuration depends on a SAML service
to provide user information and authentication.

This config file is used as the `config` input in the
[`configure-saml-authentication`][configure-saml-authentication] task.

By default, the [`configure-saml-authentication`][configure-saml-authentication] task
will create an admin client for use with the BOSH Director.
If you wish to prevent this, add `skip-bosh-admin-client-creation: true` to the config file.

{% code_snippet 'examples', 'saml-auth-configuration' %}

!!! info 
    saml authentication requires the <a href="#uaa-authentication">uaa env</a> format

The `saml-configuration` properties configures Ops Manager's usage of an SAML provider.
The [Ops Manager API Docs][opsman-api-saml] have more information
about the particular keys used in this configuration.

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

{% code_snippet 'examples', 'state' %}

The file contains two properties:

1. `iaas` is the iaas the ops manager vm is hosted on. (`gcp`, `vsphere`, `aws`, `azure`, `openstack`)
2. `vm_id` is the VM unique identifier for the VM. For some IAAS, the vm ID is the VM name.

### opsman image

This file is an [artifact from Pivnet](https://network.pivotal.io/products/ops-manager), which contains the VM image on an IAAS.
For vsphere and openstack, it is a full disk image.
For AWS, GCP, and Azure, it is the YAML file of the image locations.

An example on how to pull the AWS image resource using the [Pivnet Concourse Resource](https://github.com/pivotal-cf/pivnet-resource).

```yaml
resource_types:
- name: pivnet
  type: docker-image
  source:
    repository: pivotalcf/pivnet-resource
    tag: latest-final
resources:
- name: opsman-image
  type: pivnet
  source:
    api_token: ((pivnet_token))
    product_slug: ops-manager
    product_version: 2.*
    sort_by: semver
jobs:
- name: get-the-resource
  plan:
  - get: opsman-image
    params:
      globs: ["*AWS*.yml"]
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

An example on how to pull the vSphere stemcell using the [Pivnet Concourse Resource](https://github.com/pivotal-cf/pivnet-resource).

```yaml
resource_types:
- name: pivnet
  type: docker-image
  source:
    repository: pivotalcf/pivnet-resource
    tag: latest-final
resources:
- name: stemcell
  type: pivnet
  source:
    api_token: ((pivnet_token))
    product_slug: stemcells
    product_version: 3541.*
    sort_by: semver
jobs:
- name: get-the-resource
  plan:
  - get: stemcell
    params:
      globs: ["*vsphere*.tgz"]
```

### product

The `product` input requires a single tile file (`.pivotal`) as downloaded from Pivnet.

An example on how to pull the PAS tile using the [Pivnet Concourse Resource](https://github.com/pivotal-cf/pivnet-resource).

```yaml
resource_types:
- name: pivnet
  type: docker-image
  source:
    repository: pivotalcf/pivnet-resource
    tag: latest-final
resources:
- name: stemcell
  type: pivnet
  source:
    api_token: ((pivnet_token))
    product_slug: elastic-runtime
    product_version: 2.*
    sort_by: semver
jobs:
- name: get-the-resource
  plan:
  - get: product
    params:
      globs: ["*cf*.pivotal"]
```

!!! warning
    This file cannot be manually created. It is a file that must retrieved from Pivnet.

### download-product-config

The `config` input for a download product task expects to have a `download-config.yml` file.
The configuration of the `download-config.yml` looks like this:

{% code_snippet 'examples', 'download-product-config' %}

[configure-authentication]: task.md#configure-authentication
[configure-ldap-authentication]: task.md#configure-ldap-authentication
[configure-saml-authentication]: task.md#configure-saml-authentication
[export-installation]: task.md#export-installation
[import-installation]: task.md#import-installation
[staged-config]: task.md#staged-config
[staged-director-config]: task.md#staged-director-config

{% include ".external_link_url.md" %}
