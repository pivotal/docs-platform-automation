Extracting a director configuration file, an externalized config that lives outside of Ops Manager, can make it easier to manage multiple foundations as well as help with:

- traceability
- avoiding configuration drift
- configuration promotion


## Prerequisites
To extract the configuration for an director, you will first need to do the following:

1. Create the infrastructure for your installation. To make the infrastructure creation easier, consider using terraform to create the resources needed:

      1. [terraforming-aws][terraforming-aws]
      1. [terraforming-gcp][terraforming-gcp]
      1. [terraforming-azure][terraforming-azure]
      1. [terraforming-vsphere][terraforming-vsphere]
      1. [terraforming-openstack][terraforming-openstack]

1. Install Ops Manager using the [create-vm][create-vm] task

1. (Optional) Configure Ops Manager _manually_ within the Ops Manager UI (Instructions for doing so can be found
using the [Official-Pivotal-Platform-Documentation][pivotal-install-docs])


## Extracting Configuration
[om] has a command called [staged-director-config], which is used to extract
the Ops Manager and the BOSH director configuration from the targeted foundation.

{% include ".missing_fields_opsman_director.md" %}

Sample usage:  
`om --env env.yml staged-director-config > director.yml`  
will give you the whole configuration of Ops Manager in a single yml file.
It will look more or less the same as the example above. You can check it
in to your VCS.

The following is an example configuration file for Ops Manager that might return
after running this command:
{% code_snippet 'examples', 'director-configuration' %}

## Configuring Director Using Config File
Now you can modify the settings in the configuration file directly instead of
operating in the web ui. After you finish editing the file, the configuration
file will need to apply back to the Ops Manager instance. The command
[configure-director] will do the job.

Sample usage:  
`om --env env.yml configure-director --config director.yml`  


## Promoting Ops Manager to Another Foundation
The configuration file is the exact state of a given foundation, it contains
some environment specific properties. You need to manually edit those
properties to reflect the state of the new foundation. Or, when extracting
the configuration file from the foundation, you can use the flag
`--include-placeholders`, it will help to parameterize some variables to
ease the process of adapt for another foundation.

## VM Extensions
You may specify custom VM extensions to be used in deployments.
To learn more about how various IAAS's support and use these extensions,
[see the Bosh docs][bosh-vm-extensions].

Using VM Extensions for your director configuration
is an _advanced feature_ of Ops Manager. 
Sometimes it is necessary to define these extensions
in order to perform certain tasks on your Ops Manager director,
but they are not required to run a foundation(s),
and will change default behavior if defined.

Use at your own discretion.

In the following example, two new VM extensions are defined
and will be added to the list of available extensions on the next [`configure-director`][configure-director].
This can be added to the end of your existing `director.yml`, 
or defined independently and set with no other configurations present.

There are no default VM Extensions on a deployed Ops Manager.

`director.yml` Example:
```yaml
vmextensions-configuration:
- name: a_vm_extension
  cloud_properties:
    source_dest_check: false
- name: another_vm_extension
  cloud_properties:
    foo: bar
...
```

## VM Types
You may specify custom VM types to be used in deployments.
To learn more about how various IAAS's support and use these types,
[see the Bosh docs][bosh-vm-types].

Using VM Types for your director configuration
is an _advanced feature_ of Ops Manager. 
VM Types are not required to run a foundation(s),
and will change default behavior if defined.

Use at your own discretion.

In the following example, two new VM types are defined
and will be added to the list of available types on the next [`configure-director`][configure-director].
This can be added to the end of your existing `director.yml`, 
or defined independently and set with no other configurations present.

`director.yml` Example:
```yaml
vmtypes-configuration:
  custom_only: false
  vm_types:
  - name: x1.large
    cpu: 8
    ram: 8192
    ephemeral_disk: 10240
  - name: mycustomvmtype
    cpu: 4
    ram: 16384
    ephemeral_disk: 4096
...
```

!!! note "Precedence"
    - If `custom_only` is `true`,
    the VM types specified in your configuration will replace the entire list of available VM types in the Ops Manager. 
    - If the property is set to false or is omitted, 
    `configure_director` will append the listed VM types to the list of default VM types for your IaaS. 
    - If a specified VM type is named the same as a predefined VM type, it will overwrite the predefined type. 
    - If multiple specified VM types have the same name, the one specified last will be created. 
    - Existing custom VM types do not persist across configure-director calls, 
    and it should be expected that the entire list of custom VM types is specified in the director configuration.

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
