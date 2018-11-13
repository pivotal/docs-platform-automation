## Generating Product Configuration
To generate the configuration for a tile, you will need the following:

1. a running Ops Manager
  - this is accomplished by running the following tasks:
      - [create-vm]
      - [configure-authentication] or [configure-saml-authentication]
      - [configure-director]
      - [apply-director-changes]

1. The tile you wish to have a config file for needs to be [uploaded and staged][uploaded-and-staged] in the Ops Manager
environment

1. Configure the tile _manually_ within the Ops Manager UI (Instructions for PAS can be found
using the [Official PCF Documentation])

1. Run the following command to get the staged config:

```bash
docker import ${PLATFORM_AUTOMATION_IMAGE_TGZ} pcf-automation-image
docker run -it --rm -v $PWD:/workspace -w /workspace pcf-automation-image \
om --env ${ENV_FILE} staged-config --product-name ${PRODUCT_SLUG} --include-credentials
```

Where `${PLATFORM_AUTOMATION_IMAGE_TGZ}` is the image file downloaded from Pivnet,and `${ENV_FILE}` is the [env file] required for all tasks, and `${PRODUCT_SLUG}` is the name of the product
downloaded from [pivnet]. The resulting file can then be parameterized, saved, and uploaded to a
persistent blobstore(i.e. s3, gcs, azure blobstore, etc).

Alternatively, you can add the following task to your pipeline to generate and persist this for you:

{% code_snippet 'pivotal/platform-automation', 'staged-config' %}

{% include ".internal_link_url.md" %}
{% include ".external_link_url.md" %}