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
parametrized template for use.

## Using variables
In the Platform Automation task, you can choose to parametrize the specific entries in the configuration
file, by using the `((parametrized-value))` syntax, and then defining the `parametrized-value` in a
separate variable file.
For example, to add two variables to a YAML document (base.yml):

```yaml
s3_bucket_name: ((foundation_one_bucket))
domain_name: ((foundation_one_domain_name))
```

In your vars.yml file, define the parametrized values (vars.yml):

```yaml
foundation_one_bucket: aws-bucket-one
foundation_one_domain_name: foundation.one.domain.com
```

To check the base.yml has the variables defined in vars.yml, you can run:  
`om interpolate --config base.yml --vars-file vars.yml`  
If everything works as expected, you should see the following output:

```yaml
s3_bucket_name: aws-bucket-one
domain_name: foundation.one.domain.com
```

Otherwise you will receive an error message indicating missing variables:
```
could not execute "interpolate": Expected to find variables: ((missing-value))
```

!!! info
    If you are using an additional secrets manager, such as credhub, you can add the flag
    `--skip-missing` to your `om interpolate` call to allow parametrized variables to 
    still be present in your config after interpolation, to be later filled in by 
    interpolating with your secrets manager. See the [Secrets Handling][secrets-handling] page for a more
    detailed explanation.

## Why use variables if you're already using a secrets manager?
[Secrets Handling][secrets-handling] is a secure way to store sensitive information about your foundation, such as
access keys, passwords, ssh keys, etc. The following flowchart gives an example workflow on how you might use 
a mix of a secrets manager and vars files across multiple foundations with a single shared `base_vars_template`, 
that can be used to generate the `interpolated_vars` unique to a particular foundation, and passed into the relevant 
tasks. A separate `var_template.yml` could be used for every foundation to give unique credentials to those
foundations. More common shared settings could be included in the `vars_file.yml`.

{% include "./variables-interpolate-flowchart-independent.mmd" %}

Alternatively, you can keep all of your vars in the same file for a foundation and mix parametrized and 
unparametrized values. The interpolated vars file can be used directly in any task that allows for them.
The trade-off for this method is the mixed vars file would be tied to a single foundation, rather than 
have a single `base_vars_template.yml` shared across foundations.

{% include "./variables-interpolate-flowchart-mixed.mmd" %}


## Using variables in the Platform Automation Tasks

Some Platform Automation tasks have an optional vars input. Using the flow described above, these files can
be plugged in to the tasks.

An Example [Task](../reference/task.md#test-interpolate) has been provided to allow pipeline testing before
installing Ops Manager and PCF.
An example pipeline for this is below:

```yaml
jobs:
- name: test-interpolate
  plan:
  - get: <the-resource-contain-base-config-file>
  - get: <the-resource-contain-vars-files>
  - get: platform-automation-image
    params:
      unpack: true
  - get: platform-automation-tasks
    params:
      unpack: true
  - task: interpolate
    image: platform-automation-image
    file: platform-automation-tasks/tasks/test-interpolate.yml
    input_mapping:
      config: <the-resource-contain-base-config-file>
      vars: <the-resource-contain-vars-file>
    params:
      VARS_FILES: vars/vars.yml # vars/vars2.yml
      CONFIG_FILE: base.yml
      SKIP_MISSING: true       # false to enable strict interpolation  

```

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
