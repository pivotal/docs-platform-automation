# Configuring a Director config file

Extracting a director configuration file, an externalized config that lives outside of VMware Tanzu Operations Manager, can make it easier to manage multiple foundations as well as help with:

- traceability
- avoiding configuration drift
- configuration promotion


## Prerequisites

To extract the configuration for a director, you will first need a Tanzu Operations Manager vm.
For detailed instructions, follow the [Installing Tanzu Operations Manager](./installing-opsman.md) how-to guide.

## Extracting configuration

[om](https://github.com/pivotal-cf/om) has a command called [staged-director-config](../tasks.md#staged-director-config), which is used to extract
the Tanzu Operations Manager and the BOSH director configuration from the targeted foundation.

<%= partial "_missing_fields_opsman_director.md" %>

Sample usage:  
`om --env env.yml staged-director-config > director.yml`  

This gives you the whole configuration of Tanzu Operations Manager in a single yaml file.
It will look more or less the same as the example above. You can check it
in to your VCS.

The following is an example configuration file for Tanzu Operations Manager that might return
after running this command:
---excerpt--- "examples/director-configuration"

## Configuring Director using config file

Now you can modify the settings in the configuration file directly instead of
operating in the web ui. After you finish editing the file, the configuration
file will need to apply back to the Tanzu Operations Manager instance. The command
[configure-director](../tasks.md#configure-director) will do the job.

Sample usage:  
`om --env env.yml configure-director --config director.yml`  


## Promoting Tanzu Operations Manager to another foundation

The configuration file is the exact state of a given foundation, it contains
some environment specific properties. You need to manually edit those
properties to reflect the state of the new foundation. Or, when extracting
the configuration file from the foundation, you can use the flag
`--include-placeholders`, it will help to parameterize some variables to
ease the process of adapt for another foundation.

## VM extensions

You may specify custom VM extensions to be used in deployments.
To learn more about how various IAAS's support and use these extensions,
[see the Bosh docs](https://bosh.io/docs/cloud-config/#vm-extensions).

Using VM Extensions for your director configuration
is an _advanced feature_ of Tanzu Operations Manager.
Sometimes it is necessary to define these extensions
in order to perform certain tasks on your Tanzu Operations Manager director,
but they are not required to run a foundation(s),
and will change default behavior if defined.

Use at your own discretion.

In the following example, two new VM extensions are defined
and will be added to the list of available extensions on the next [`configure-director`](../tasks.md#configure-director).
This can be added to the end of your existing `director.yml`,
or defined independently and set with no other configurations present.

There are no default VM Extensions on a deployed Tanzu Operations Manager.

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

To use VM Extensions in either your director or product,
define `additional_vm_extensions` like so:
```yaml
resource-configuration:
  director:
    additional_networks: []
    additional_vm_extensions: [a_vm_extension,another_vm_extension]
...
```

## VM types

You may specify custom VM types to be used in deployments.
To learn more about how various IAAS's support and use these types,
[see the Bosh docs](https://bosh.io/docs/cloud-config/#vm-types).

Using VM Types for your director configuration
is an advanced feature of Tanzu Operations Manager.
VM Types are not required to run a foundation(s),
and will change default behavior if defined.

Use at your own discretion.

In the following example, two new VM types are defined
and will be added to the list of available types on the next [`configure-director`](../tasks.md#configure-director).
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

<p class="note">
<span class="note__title">Note</span>
<ol>
  <li>If <code>custom_only</code> is <code>true</code>,
  the VM types specified in your configuration will replace the entire list of available VM types in the Tanzu Operations Manager.</li>
  <li>If the property is set to false or is omitted,
  <code>configure_director</code> will append the listed VM types to the list of default VM types for your IaaS.</li>
  <li>If a specified VM type is named the same as a predefined VM type, it will overwrite the predefined type.</li>
  <li>If multiple specified VM types have the same name, the one specified last will be created.</li>
  <li>Existing custom VM types do not persist across configure-director calls,
  and it should be expected that the entire list of custom VM types is specified in the director configuration.</li>
</ol>
</p>

[//]: # ({% with path="../" %})
[//]: # (    {% include ".internal_link_url.md" %})
[//]: # ({% endwith %})
[//]: # ({% include ".external_link_url.md" %})
