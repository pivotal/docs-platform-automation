# Variables

## What are Platform Automation variables?
Variables provide a way to define parameters for a YAML document. Each variable has a value
and can be referenced in one or more locations. Variables are used in the Platform Automation
[tasks][task-reference]. One example usage is in [configure director][configure-director]. 

## Why use variables?
It's typically necessary to separate passwords, certificates, S3 bucket names etc. from YAML
documents for security or multi-foundation purposes. Even though the structure
of a YAML document (manifest) does not change, these values are typically different. Variables
require special syntax in the configuration files which need them. The resulting config file is then a
parameterized template for use.

## Using variables
In the Platform Automation task, you can choose to parameterize the specific entries in the configuration
file, by using the `((parameterized-value))` syntax, and then defining the `parameterized-value` in a
separate variable file.
For example, to add two variables to a YAML document (base.yml):

```yaml
s3_access_key_id: ((access_key_id))
s3_access_secret_key: ((access_secret_key))
```

In your vars.yml file, define the parameterized values (vars.yml):

```yaml
access_key_id: Secret-Access-ID
access_secret_key: Secret-Access-Key
```

To check the base.yml has the variables definied in vars.yml, you can run:  
`om interpolate --config base.yml --vars-file vars.yml`  
If everything works as exepceted, you should see the following output:

```yaml
s3_access_key_id: Secret-Access-ID
s3_access_secret_key: Secret-Access-Key
```

Otherwise you will receive an error message indicating missing variables:
```
could not execute "interpolate": Expected to find variables: ((missing-value))
```

## Why use variables if you're already using a secrets manager?
[secrets handling] requires that all parameterized values be included in your secrets manager (i.e. credhub).
Because of this, vars files and secrets handling have to be used a little differently.
For example, rather than having credhub interpolate directly into a base.yml, credhub could replace the values of
a vars.yml.

{% include "./variables-interpolate-flowchart.mmd" %}

The primary use case for this is when deploying multiple PCF foundations. Referencing the flowchart,
a separate `var_template.yml` could be used for every foundation to give unique credentials to those
foundations. More common shared settings could be included in the `vars_file.yml`.


## Using variables in the Platform Automation Tasks

Some Platform Automation tasks have an optional vars input. Using the flow described above, these files can
be plugged in to the tasks.

An Example [Task](reference/task.md#test-interpolate) has been provided to allow pipeline testing before
installing OpsManager and PCF.
An example pipeline for this is below:

```yaml
jobs:
- name: test-interpolate
  plan:
  - get: <the-resource-contain-base-config-file>
  - get: <the-resource-contain-vars-files>
  - get: pcf-automation-image
    params:
      unpack: true
  - get: pcf-automation-tasks
    params:
      unpack: true
  - task: interpolate
    image: pcf-automation-image
    file: pcf-automation-tasks/tasks/test-interpolate.yml
    input_mapping:
      config: <the-resource-contain-base-config-file>
      vars: <the-resource-contain-vars-file>
    params:
      VARS_FILES: vars/vars.yml # vars/vars2.yml
      CONFIG_FILE: base.yml

```




{% include ".internal_link_url.md" %}
{% include ".external_link_url.md" %}
