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

{% include ".docker-import-director.md" %}

Where `${PLATFORM_AUTOMATION_IMAGE_TGZ}` is the image file downloaded from Pivnet, and `${ENV_FILE}` is the [env file]
required for all tasks. The resulting file can then be parameterized, saved, and uploaded to a persistent
blobstore(i.e. s3, gcs, azure blobstore, etc).

Alternatively, you can add the following task to your pipeline to generate and persist this for you:

{% code_snippet 'pivotal/platform-automation', 'staged-director-config' %}

{% include ".missing_fields_opsman_director.md" %}

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
