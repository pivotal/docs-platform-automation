Extracting a director configuration file, an externalized config that lives outside of OpsManager, can make it easier to manage multiple foundations as well as help with:

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

1. Install Ops Manager

1. (Optional) Configure Ops Manager _manually_ within the Ops Manager UI (Instructions for doing so can be found
using the [Official PCF Documentation])


## Extracting Configuration
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
{% code_snippet 'examples', 'director-configuration' %}

## Configuring Director Using Config File
Now you can modify the settings in the configuration file directly instead of
operating in the web ui. After you finish editing the file, the configuration
file will need to apply back to the OpsManager instance. The command
[configure-director] will do the job.

Sample usage:  
`om --env env.yml configure-director --config director.yml`  


## Promoting OpsManager to Another Foundation
The configuration file is the exact state of a given foundation, it contains
some environment specific properties. You need to manually edit those
properties to reflect the state of the new foundation. Or, when extracting
the configuration file from the foundation, you can use the flag
`--include-placeholders`, it will help to parameterize some variables to
ease the process of adapt for another foundation.



{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
