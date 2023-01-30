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
If we want to have Ops Manager create a new certificate authority for us, we can use the Ops Manager API via `om` CLI:
```bash
om -e env.yml generate-certificate-authority
```
The new CA will be assigned a guid for reference in future API calls, so we need to store it somewhere.

### Configure Ops Manager to Use an Existing Certificate Authority
If we have a signed certificate authority that we want Ops Manager to use, we can provide that to the Ops Manager API via `om` CLI:
```bash
om -e env.yml create-certificate-authority --certificate-pem certificate.pem --private-key-pem privatekey.pem
```
The new CA will be assigned a guid for reference in future API calls, so we need to store it somewhere.

### Apply Changes
After configuring a new certificate authority, Ops Manager needs to apply changes before the new CA is available to generate and sign certificates. This also registers the CA with components so that they will trust certificates from the new CA.

## Activate the New Certificate Authority
We need to set our new certificate authority as the active certificate authority. After this, any certificates created by the Credhub will be signed by the new CA.
```bash
om -e env.yml activate-certificate-authority --id <new-ca-guid>
```

## Regenerate Certificates

### Non-configurable Leaf Certificates
Now that a new certificate authority is active, any internal, non-configurable certificates need to be regenerated and signed by the new CA. The Ops Manager API has a function to delete all non-configurable certificates and generate new ones using the current, active CA:
```bash
om -e env.yml regenerate-certificates
```
This will delete the existing certificates from Credhub, which causes Credhub to generate new certificates on the next run of Apply Changes.

### Configurable Certificates
Any manually configured certificates that are signed by the foudation root certificate authority need to be regenerated as well. Tanzu Application Service needs at least two configurable certificates, one for networking components and one for UAA.
After generating a new certificate, it needs to be configured in Ops Manager with a manifest file specific to the certificate. For the UAA SAML service provider credentials, here is an example manifest titled `uaa_update_template.yml`:
```yml
product-name: cf
product-properties:
  .uaa.service_provider_key_credentials:
    value:
      cert_pem: ((certificate))
      private_key_pem: ((key))
```
<!-- ```yml
product-name: cf
product-properties:
  .properties.networking_poe_ssl_certs[0].certificate:
    value:
      cert_pem: ((certificate))
      private_key_pem: ((key))
``` -->

```bash
om --env env.yml generate-certificate --domains "apps.foundation.example.com" > new-cert.json
om interpolate --config key_update_template.yml --vars-file new-cert.json > key_manifest.yml
om --env env.yml configure-product -c key_manifest.yml
```

We can fetch the list of configurable certificates from the Ops Manager API:
```bash
om -e env.yml curl -p /api/v0/deployed/certificates | jq '.certificates[] | select(.configurable==true)'
```

### Apply Changes
Finally, we need to apply changes one last time in order to create and use the new certificates.

## Cleaning Up
Once the function of the foundation is validated with new certificates, the old certificate authority can be deleted.
```bash
om -e env.yml delete-certificate-authority --all-inactive
```

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
