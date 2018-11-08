## Generating Director Configuration
To generate the configuration for an Ops Manager, you will need the following (Just like a tile):

1. a running Ops Manager
  - this is accomplished by running the following tasks:
      - [create-vm]
      - [configure-authentication] or [configure-saml-authentication]
      - [configure-director]
      - [apply-director-changes]

1. Configure Ops Manager _manually_ within the Ops Manager UI (Instructions for doing so can be found
using the [Official PCF Documentation])

1. Run the following command to get the staged config:

```bash
docker import ${PLATFORM_AUTOMATION_IMAGE_TGZ} pcf-automation-image
docker run -it --rm -v $PWD:/workspace -w /workspace pcf-automation-image \
om --env ${ENV_FILE} staged-director-config --include-placeholders
```

Where `${PLATFORM_AUTOMATION_IMAGE_TGZ}` is the image file downloaded from Pivnet, and `${ENV_FILE}` is the [env file]
required for all tasks. The resulting file can then be parameterized, saved, and uploaded to a persistent
blobstore(i.e. s3, gcs, azure blobstore, etc).

Alternatively, you can add the following task to your pipeline to generate and persist this for you:

{% code_snippet 'pivotal/platform-automation', 'staged-director-config' %}

!!! note
    staged-director-config will not be able to grab all sensitive fields in your Ops Manager installation (for example: vcenter_username and vcenter_password if using vsphere). To find these missing fields, please refer to the <a href="https://docs.pivotal.io/pivotalcf/opsman-api/">Ops Manager API Documentation</a>

{% include "_internal_link_url.md" %}
{% include "_external_link_url.md" %}