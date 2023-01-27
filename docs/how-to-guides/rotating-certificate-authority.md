# Writing a Pipeline to Rotate the Foundation Certificate Authority

This how-to-guide shows you how to write a pipeline for rotating the
certificate authority on an existing Ops Manager.

## Prerequisites
1. A pipeline, such as one created in [Installing Ops Manager][install-how-to] 
   or [Upgrading an Existing Ops Manager][upgrade-how-to].
1. A fully configured Ops Manager and Director.
1. The Platform Automation Toolkit Docker Image [imported and ready to run][running-commands-locally].

## Generating a Root Certificate Authority
There are two methods to configure a new root certificate authority in Ops
Manager:

1. Use Ops Manager to generate a new certificate authority.
1. Give Ops Manager an existing root certificate authority to use.

### Generate a New Certificate Authority

### Configure Ops Manager to Use an Existing Certificate Authority

### Apply Changes
After configuring a new certificate authority, Ops Manager needs to apply changes before the new CA is recognized by components.

## Activate the New Certificate Authority
We need to set our new certificate authority as the active certificate authority. After this, any certificates created by the Credhub will be signed by the new CA.

## Regenerate Certificates

### Non-configurable Leaf Certificates
Now that a new certificate authority is active, any internal, non-configurable certificates need to be regenerated and signed by the new CA.

### Configurable Certificates
Manually configured certificates need to be regenerated as well.

### Apply Changes
Finally, we need to apply changes one last time in order to start using all of the new certificates.

## Cleaning Up
Once the function of the foundation is validated with new certificates, the old certificate authority can be deleted.

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
