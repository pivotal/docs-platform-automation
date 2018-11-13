## Generating an Env File
Almost all [`om`][om] commands require an env file
to hit authenticated API endpoints.

The configuration for authentication has a dependency on either username/password

{% code_snippet 'pivotal/platform-automation', 'env' %}

or, if using SAML, a client-id and client-secret.

{% code_snippet 'pivotal/platform-automation', 'env-uaa' %}

While `decryption-passphrase` is nominally optional,
if you intend to use a single `env.yml` for an entire pipeline,
it will be necessary to include for use with the `import-installation` step.

{% include ".internal_link_url.md" %}
{% include ".external_link_url.md" %}