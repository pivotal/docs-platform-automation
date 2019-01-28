## Generating an Env File
Almost all [`om`][om] commands require an env file
to describe the Ops Manager Authenticated API endpoint (This is the URL you connect to opsmanager with).

The configuration for authentication has a dependency on either username/password

{% code_snippet 'examples', 'env' %}

or, if using SAML, a client-id and client-secret.

{% code_snippet 'examples', 'env-uaa' %}

While `decryption-passphrase` is nominally optional,
if you intend to use a single `env.yml` for an entire pipeline,
it will be necessary to include for use with the `import-installation` step.

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
