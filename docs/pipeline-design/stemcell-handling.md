# Stemcell Handling

## What is Stemcell Handling?
In Ops Manager, every product uploaded and staged needs to be given a [stemcell][bosh-stemcell] in 
order to operate. By default, every stemcell uploaded to Ops Manager will automatically associate
with any new or existing products. Using the automation tasks, this default can be overridden to
not have a stemcell associate with any products, and can be manually assigned as deemed necessary
by the user. 

## Why do your Stemcell Handling Manually?
Unless there is a specific need to manually handle the stemcells in Ops Manager, it is recommended
to use the default. A common use case for manual stemcell handling is updating the product stemcells 
one at a time to minimize downtime during apply changes. This is particularly beneficial in environments
with large numbers of tiles that share the same stemcell. 

## How to use the Stemcell Handling Tasks in Automation
Platform Automation has tasks that will assist in the manual handling of stemcells within 
Ops Manager. These tasks, in order, are:

- [download-product][download-product]
- [upload-product][upload-product]
- [upload-stemcell][upload-stemcell]
- [stage-product][stage-product]
- [assign-stemcell][assign-stemcell]

1. `download-product`: 
    Create a `config.yml` for this task using the [example provided][download-product-config]

    After running the task, the following snippet of code will run:

{% code_snippet 'pivotal/platform-automation', 'assign-stemcell-support' %}

   The task will put a config file with two values, `product` and `stemcell` into the `assign-stemcell-config`
   output directory.

2. Run the [upload-product][upload-product] and [upload-stemcell][upload-stemcell] tasks to get the 
   resources into Ops Manager.

    To upload the stemcell to Ops Manager without associating it with any product, the 
    [`upload-stemcell`][upload-stemcell] task will need to be executed with the `FLOATING_STEMCELL: false` 
    flag set.
    
    An example of this, in a pipeline:

```yaml
- task: upload-stemcell
  image: pcf-automation-image
  file: pcf-automation-tasks/tasks/upload-stemcell.yml
  input_mapping:
    env: configuration
    stemcell: downloaded-stemcell
  params:
    ENV_FILE: ((foundation))/env/env.yml
    FLOATING_STEMCELL: false
```

3. Run the [stage-product][stage-product] task.

4. Run the [assign-stemcell][assign-stemcell] task to associate the stemcell with the staged product.
   If using the `download-product` task before doing this within the same job, you must assign the config
   using the `input_mapping` key to assign the outputted config to the config that `assign-stemcell` is
   expecting. Upon successful completion, the stemcell specified in the config will be associated with the product
   specified in the config, and no other product will be associated with that stemcell.
   
    An example of this, in a pipeline:

```yaml
- task: assign-stemcell
  image: pcf-automation-image
  file: pcf-automation-tasks/tasks/assign-stemcell.yml
  input_mapping:
    env: configuration
    config: assign-stemcell-config
  params:
    ENV_FILE: ((foundation))/env/env.yml
```
   

5. [Configure Product][configure-product] and [Apply Changes][apply-changes] can then be run on the 
product as normal.

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
