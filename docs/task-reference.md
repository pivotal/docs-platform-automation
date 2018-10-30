---
title: Platform Automation for PCF Task Reference
owner: PCF Platform Automation
---

##  Platform Automation for PCF Tasks
This document lists each Platform Automation for PCF task,
and provides information about their intentions, inputs, and outputs.

The tasks are presented, in their entirety,
as they are found in the product.

The docker image can be used to invoke the tasks in each task locally.
Use `--help` for more information.

###  apply-changes

Triggers an install on the Ops Manager described by the auth file.

{% code_snippet 'pivotal/platform-automation', 'apply-changes' %}

###  apply-director-changes
`apply-changes` can also be used to trigger an install for just the BOSH Director
with the `--skip-deploy-products`/`-sdp` flag.

{% code_snippet 'pivotal/platform-automation', 'apply-director-changes' %}

###  configure-authentication
Configures Ops Manager with an internal userstore and admin user account.
See [configure-saml-authentication](#configure-saml-authentication) to configure an external SAML user store.

{% code_snippet 'pivotal/platform-automation', 'configure-authentication' %}

###  configure-director
Configures the BOSH Director with settings from a config file.
See [staged-director-config](#staged-director-config),
which can extract a config file.

{% code_snippet 'pivotal/platform-automation', 'configure-director' %}

!!! warning ""
     <strong>NOTE:</strong> For GCP, if service account is used, the property associated_service_account has to be set explicitly in the iaas-configuration section. 

###  configure-product
Configures an individual, staged product with settings from a config file.

Not to be confused with Ops Manager's
built-in [import](https://docs.pivotal.io/pivotalcf/customizing/backup-restore/restore-pcf-bbr.html#deploy-import),
which reads all deployed products and configurations from a single opaque file,
intended for import as part of backup/restore and upgrade lifecycle processes.

See [staged-config](#staged-config),
which can extract a config file,
and [upload-and-stage-product](#upload-and-stage-product),
which can stage a product that's been uploaded.

{% code_snippet 'pivotal/platform-automation', 'configure-product' %}

###  configure-saml-authentication
Configures Ops Manager with an external SAML user store and admin user account.
See [configure-authentication](#configure-authentication) to configure an internal user store.

{% code_snippet 'pivotal/platform-automation', 'configure-saml-authentication' %}

Configuring SAML has two different auth flows for the UI and the task.
The UI will have a browser based login flow.
The CLI will require `client-id` and `client-secret` as it cannot do a browser login flow.

For more details on using SAML,
please refer to the [Ops Manager documentation](https://docs.pivotal.io/pivotalcf/2-2/opsguide/config-rbac.html#enable-saml)

###  create-vm
Creates an unconfigured Ops Manager VM.

{% code_snippet 'pivotal/platform-automation', 'create-vm' %}

This task requires a config file specific to the IaaS being deployed to.
Please see the [configuration](#opsman-config) page for more specific examples.

###  credhub-interpolate
Interpolate credhub entries into configuration files

{% code_snippet 'pivotal/platform-automation', 'credhub-interpolate' %}

This task requires a valid credhub with UAA client and secret. For information on how to 
set this up, see [Getting Started](./getting-started.md#using-your-credhub)

###  delete-installation
Delete the Ops Manager Installation

{% code_snippet 'pivotal/platform-automation', 'delete-installation' %}

###  delete-vm
Deletes the Ops Manager VM instantiated by [create-vm](#create-vm).

{% code_snippet 'pivotal/platform-automation', 'delete-vm' %}

This task requires the [state file](#state) generated [create-vm](#create-vm).

###  export-installation
Exports an existing Ops Manager to a file.

This is the first part of the backup/restore and upgrade lifecycle processes.
This task is used on a fully installed and healthy Ops Manager to export
settings to an upgraded version of Ops Manager.

{% code_snippet 'pivotal/platform-automation', 'export-installation' %}
{% include "./_export_installation_note.md" %}

###  import-installation
Imports a previously exported installation to Ops Manager.

This is a part of the backup/restore and upgrade lifecycle processes.
This task is used after an installation has been exported and a new Ops Manager
has been deployed, but before the new Ops Manager is configured.

{% code_snippet 'pivotal/platform-automation', 'import-installation' %}

###  staged-config
Downloads the configuration for a product from Ops Manager.

Not to be confused with Ops Manager's
built-in [export](https://docs.pivotal.io/pivotalcf/2-1/customizing/backup-restore/backup-pcf-bbr.html#export),
which puts all deployed products and configurations into a single file,
intended for import as part of backup/restore and upgrade lifecycle processes.

{% code_snippet 'pivotal/platform-automation', 'staged-config' %}

###  staged-director-config
Downloads configuration for the BOSH director from Ops Manager.

{% code_snippet 'pivotal/platform-automation', 'staged-director-config' %}

The configuration is exported to the `generated-config` output.
It does not extract credentials from Ops Manager
and replaced them all with YAML interpolation `(())` placeholders.
This is to ensure that credentials are never written to disk.
The credentials need to be provided from an external configuration when invoking [configure-director](#configure-director).

###  test
An example task to ensure the assets and docker image are setup correctly in your concourse pipeline.

{% code_snippet 'pivotal/platform-automation', 'test' %}

###  upgrade-opsman
Upgrades an existing Ops Manager to a new given Ops Manager version

{% code_snippet 'pivotal/platform-automation', 'upgrade-opsman' %}

For more information about this task and how it works, see the [upgrade](upgrade.md) page.

###  upload-and-stage-product
Uploads and stages product to the Ops Manager specified in the config file.

{% code_snippet 'pivotal/platform-automation', 'upload-and-stage-product' %}

###  upload-stemcell
Uploads a stemcell to Ops Manager.

Note that the filename of the stemcell must be exactly as downloaded from Pivnet.
Ops Manager parses this filename to determine the version and OS of the stemcell.

{% code_snippet 'pivotal/platform-automation', 'upload-stemcell' %}

##  Inputs
These are the inputs that can be provided to the tasks.
Each task can only take a specific set, indicated under the `inputs` property of the YAML.

###  env

The `env` input for a task expects to have a `env.yml` file.
This file contains properties for targeting and logging into the Ops Manager API.

#### basic authentication
{% code_snippet 'pivotal/platform-automation', 'env' %}

#### uaa authentication
{% code_snippet 'pivotal/platform-automation', 'env-uaa' %}


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

###  auth

There are two different authentication methods that Ops Manager supports.

#### basic authentication
The configuration for authentication has a dependency on username/password.
This configuration format matches the configuration for setting up authentication.
See the task for the [`configure-authentication`](#configure-authentication) for details.

{% code_snippet 'pivotal/platform-automation', 'auth-configuration' %}

!!! note ""
     <strong>NOTE:</strong> basic authentication supports both <a href="#basic-authentication">basic env</a> and <a href="#uaa-authentication">uaa env</a> formats 

#### saml authentication
The configuration for authentication has a dependency on SAML.
This configuration format matches the configuration for setting up authentication.
See the task for the [`configure-saml-authentication`](#configure-saml-authentication) for details.

{% code_snippet 'pivotal/platform-automation', 'saml-auth-configuration' %}

!!! note ""
     <strong>NOTE:</strong> saml authentication requires the <a href="#uaa-authentication">uaa env</a> format 

The `saml-configuration` properties configures the SAML provider.
The [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#setting-up-with-saml) has more information about the values

###  opsman config
The config for an Ops Manager described IAAS specific information for creating the VM -- i.e. VM flavor (size), IP addresses

The `config` input for opsman task expects to have a `opsman.yml` file.
The configuration of the `opsman.yml` is IAAS specific.

Specific examples for each IaaS are as follows:

####  AWS
These required properties are adapted from the instructions outlined in
[Launching an Ops Manager Director Instance on AWS](https://docs.pivotal.io/pivotalcf/customizing/pcf-aws-manual-config.html)

{% code_snippet 'pivotal/platform-automation', 'aws-configuration' %}

####  Azure
These required properties are adapted from the instructions outlined in
[Launching an Ops Manager Director Instance on Azure](https://docs.pivotal.io/pivotalcf/customizing/azure.html)

{% code_snippet 'pivotal/platform-automation', 'azure-configuration' %}


####  GCP
These required properties are adapted from the instructions outlined in
[Launching an Ops Manager Director Instance on GCP](https://docs.pivotal.io/pivotalcf/customizing/gcp-om-deploy.html)

{% code_snippet 'pivotal/platform-automation', 'gcp-configuration' %}

Support for Shared VPC is done via
[configuring the `vpc_subnet` path](https://cloud.google.com/vpc/docs/provisioning-shared-vpc#creating_an_instance_in_a_shared_subnet)
to include the host project id, region of the subnet, and the subnet name.

For example:

`projects/[HOST_PROJECT_ID]/regions/[REGION]/subnetworks/[SUBNET]` 

####  Openstack
These required properties are adapted from the instructions outlined in
[Launching an Ops Manager Director Instance on Openstack](https://docs.pivotal.io/pivotalcf/customizing/openstack-om-config.html)

{% code_snippet 'pivotal/platform-automation', 'openstack-configuration' %}


####  vSphere
These required properties are adapted from the instructions outlined in
[Deploying BOSH and Ops Manager to vSphere](https://docs.pivotal.io/pivotalcf/customizing/deploying-vm.html)

{% code_snippet 'pivotal/platform-automation', 'vsphere-configuration' %}

###  director config
The config director will set the bosh tile (director) on Ops Manager.

The `config` input for a director task expects to have a `director.yml` file.
The configuration of the `director.yml` is IAAS specific for some properties -- i.e. networking.

There are two ways to build a director config.

1. Using an already deployed Ops Manager, you can extract the config using [staged-director-config](#staged-director-config).
2. Deploying a brand new Ops Manager requires more effort for a `director.yml`.
   The configuration of director is variables based on the features enabled.
   For brevity, this `director.yml` is a basic example for vsphere.
   
{% code_snippet 'pivotal/platform-automation', 'director-configuration' %}

The IAAS specific configuration can be found in the Ops Manager API documentation.

Included below is a list of properties that can be set in the `director.yml`
and a link to the API documentation explaining any IAAS specific properties.

* `az-configuration` - a list of availability zones [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#updating-availability-zones-experimental)
* `iaas-configuration` - configuration for the bosh IAAS CPI [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#updating-director-and-iaas-properties-experimental)
* `network-assignment` - the network the bosh director is deployed to [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#updating-network-and-availability-zone-assignments)
* `networks-configuration` - a list of named networks [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#updating-networks-experimental)
* `director-configuration` - properties for the bosh director [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#updating-director-and-iaas-properties-experimental)
* `resource-configuration` - IAAS VM flavor for the bosh director [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#configuring-resources-for-a-job)
* `security-configuration` - security properties for the bosh director [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#updating-director-and-iaas-properties-experimental)
* `syslog-configuration` - configure the syslog sinks for the bosh director [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#updating-director-and-iaas-properties-experimental)
* `vmextensions-configuration` - create/update/delete vm extensions [Ops Manager API](http://docs.pivotal.io/pivotalcf/2-1/opsman-api/#updating-or-creating-a-new-vm-extension)

#### GCP Shared VPC

Support for Shared VPC is done via configuring the `iaas_identifier` path for the [infrastructure subnet](https://docs.pivotal.io/pivotalcf/customizing/gcp-prepare-env.html#create_network),
which includes the host project id, region of the subnet, and the subnet name.

For example:

`[HOST_PROJECT_ID]/[NETWORK]/[SUBNET]/[REGION]`

###  product config
There are two ways to build a product config.

1. Using an already deployed product (tile), you can extract the config using [staged-config](#staged-config).
1. Use an example and fill in the values based on the meta information from the tile.
For brevity, this `product.yml` is a basic example for `healthwatch`.
  
{% code_snippet 'pivotal/platform-automation', 'product-configuration' %}

Included below is a list of properties that can be set in the `product.yml`
and a link to the API documentation explaining the properties.

* `product-properties` - properties for the tile [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#updating-a-selector-property)
* `network-properties` - a list of named networks to deploy the VMs to [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#configuring-networks-and-azs)
* `resource-config` - for the jobs of the tile [Ops Manager API](https://docs.pivotal.io/pivotalcf/2-1/opsman-api/#configuring-resources-for-a-job)

###  state
This file contains that meta-information needed to manage the Ops Manager VM.
The `state` input for a opsman VM task expects to have a `state.yml` file.

{% code_snippet 'pivotal/platform-automation', 'state' %}

The file contains two properties:

1. `iaas` is the iaas the ops manager vm is hosted on. (`gcp`, `vsphere`, `aws`, `azure`, `openstack`)
2. `vm_id` is the VM unique identifier for the VM. For some IAAS, the vm ID is the VM name.

###  opsman image
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

###  installation
The file contains the information to restore an Ops Manager VM.
The `installation` input for a opsman VM task expects to have a `installation.zip` file.

This file can be exported from an Ops Manager VM using the [export-installation](#export-installation).
This file can be imported to an Ops Manager VM using the [import-installation](#import-installation).

!!! warning ""
     <strong>NOTE:</strong> This file cannot be manually created. It is a file that must be generated via the export function of Ops Manager. 

###  stemcell
This `stemcell` input requires the stemcell tarball (`.tgz`) as downloaded from Pivnet.
It must be in the original filename as that is used by Ops Manager to parse metadata.
The filename could look like `bosh-stemcell-3541.48-vsphere-esxi-ubuntu-trusty-go_agent.tgz`.

!!! warning ""
     <strong>NOTE:</strong> This file cannot be manually created. It is a file that must retrieved from Pivnet. 

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
 
###  product
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

!!! warning ""
     <strong>NOTE:</strong> This file cannot be manually created. It is a file that must retrieved from Pivnet. 

