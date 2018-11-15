# Externalized OpsManager Config


## Introduction
Usually, the operator configures the OpsManager through the web UI. 
The targeted OpsManager is considered as the source of truth, meaning
that it holds every aspect of the configuration of a foundation. However, managing the configuration of multiple foundations 
through the web UI can be challenging or recreating the foundation over and over can be diffucult. This is mainly because :
* avoiding configuration drift among foundations can be difficult
* promoting configuration from one foundation can be difficult
* no explicit versioning on configuration makes it difficult to trace

One pattern emerges to address the above problems and that is to externalize the
configuration.

## What is externalized configuration?
At a high-level, an externalized config is a configuration file that lives
outside of OpsManager. Because the configuration file essentially 
configures OpsManager to a known state, it implies the configuration
file is the source of truth. And since the file is just a plain-text
documentation, it can be easily versioned using a Version Control System (VCS) like git. For
multiple foundations, one approach is to promote the entire configuration
file. 

## Why use externalized configuration?
### Traceability
Essentially, the configuration file is a plain-text YAML documentation,
it could be easily versioned using VCS like git. This way operators have
maximum traceability of the state of OpsManager. Every single change of
the configuration can be reviewed and approved.

### Avoiding configuration drift
As the configuration for a given foundation is essentially code, it is
very easy to take a diff of a plain-text documentation. Or even better,
various tools can compare YAML documentation to ignore the difference
in style, so that even a single character difference can be caught and
prevented if the difference is an accident. Also, all the configuration
files can be centralized and structured to ease the management.

### Configuration promotion
Since the configuration file is the source of truth, if it is tested on
the sandbox/dev environment, it can be promoted to a production environment
easily. [Promote to another foundation](#promote-to-another-foundation) section will talk in more detail about how to apply the
configuration file to an foundation.

## How to use externalized config
To get started with externalized config, you would first extract a configuration
file from an existing foundation.

### Extract configuration
[om] has a command called [staged-director-config], which is used to extract
the OpsManager and the BOSH director configuration from the targeted foundation.

Sample usage:  
`om --env env.yml staged-director-config > director.yml`  
will give you the whole configuration of OpsManager in a single yml file.
It will look more or less the same as the example above. You can check it
in to your VCS.

The following is an example configuration file for OpsManager that might return
after running this command:
{% code_snippet 'pivotal/platform-automation', 'director-configuration' %}

### Configure using configuration file
Now you can modify the settings in the configuration file directly instead of
operating in the web ui. After you finish editing the file, the configuration
file will need to apply back to the OpsManager instance. The command 
[configure-director] will do the job.

Sample usage:  
`om --env env.yml configure-director --config director.yml`  


### Promote to another foundation
The configuration file is the exact state of a given foundation, it contains
some environment specific properties. You need to manually edit those 
properties to reflect the state of the new foundation. Or, when extracting
the configuration file from the foundation, you can use the flag 
`--include-placeholders`, it will help to parameterize some variables to
ease the process of adapt for another foundation.

After you are satisfied with the configuration change, you can use [om]
to apply the configuration: `om --env some-other-env.yml configure-director --config adapted-director.yml`






{% include ".internal_link_url.md" %}
{% include ".external_link_url.md" %} 
