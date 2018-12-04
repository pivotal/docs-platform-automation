## Generating an Auth File
These configuration formats match the configuration for setting up authentication.
See the documentation for the [`configure-authentication`][configure-authentication]
or [`configure-saml-authentication`][configure-saml-authentication] task for details.

The configuration for authentication has a dependency on either username/password,

{% code_snippet 'pivotal/platform-automation', 'auth-configuration' %}

SAML configuration information,

{% code_snippet 'pivotal/platform-automation', 'saml-auth-configuration' %}

or LDAP configuration information.

{% code_snippet 'pivotal/platform-automation', 'ldap-auth-configuration' %}

## Managing Configuration, Auth, and State Files
To use all these files with the Concourse tasks that require them,
you need to make them available as Concourse Resources.
They’re all text files.
There are many resource types that can work for this.
In our examples, we use a git repository.
As with the tasks and image,
you’ll need to declare a resource in your pipeline for each repo you need.

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md"%}
