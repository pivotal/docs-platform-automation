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
- [stage-product][stage-product]
- [upload-stemcell][upload-stemcell]
- [assign-stemcell][assign-stemcell]

1. `download-product`:

    Create a `config.yml` for this task using the [example provided][download-product-config].

    After running the task, a file named `assign-stemcell.yml` is outputted.
    The task will put a config file with two values, `product` and `stemcell` into the `assign-stemcell-config`
    output directory. This can be used with [assign-stemcell][assign-stemcell] to ensure the _latest_ stemcell is
    used with that product.

2. Run the [upload-product][upload-product] and [stage-product][stage-product] tasks to get the
   resources into Ops Manager.

3. Run the [upload-stemcell][upload-stemcell] task.

    To upload the stemcell to Ops Manager without associating it with any product, the
    [`upload-stemcell`][upload-stemcell] task will need to be executed with the `FLOATING_STEMCELL: false` 
    flag set.
    
    An example of this, in a pipeline:

```yaml
- task: upload-stemcell
  image: platform-automation-image
  file: platform-automation-tasks/tasks/upload-stemcell.yml
  input_mapping:
    env: configuration
    stemcell: downloaded-stemcell
  params:
    ENV_FILE: ((foundation))/env/env.yml
    FLOATING_STEMCELL: false
```

!!! warning
    `upload-stemcell` should not be run until after the `stage-product` task has completed. When the two tasks are run in the
    opposite order, the stemcell will still auto-associate with the product.


4. Run the [assign-stemcell][assign-stemcell] task to associate the stemcell with the staged product.
   If using the `download-product` task before doing this within the same job, you must assign the config
   using the `input_mapping` key to assign the outputted config to the config that `assign-stemcell` is
   expecting. Upon successful completion, the stemcell specified in the config will be associated with the product
   specified in the config, and no other product will be associated with that stemcell.
   
    An example of this, in a pipeline:

```yaml
- task: assign-stemcell
  image: platform-automation-image
  file: platform-automation-tasks/tasks/assign-stemcell.yml
  input_mapping:
    env: configuration
    config: assign-stemcell-config
  params:
    ENV_FILE: ((foundation))/env/env.yml
```
   

5. [Configure Product][configure-product] and [Apply Changes][apply-changes] can then be run on the
product as normal.

## How to Download a Specific Stemcell

Platform Automation can be used to download a specific stemcell. In order to do so, create a `config.yml` for this
task using the [example provided][download-stemcell-product-config].

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
