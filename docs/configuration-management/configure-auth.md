## Generating an Auth File
Ops Manager's authentication system can be configured several ways.
The format of the configuration file varies
according to the authentication method to be used.

For more information about these choices,
see the [appropriate section][inputs-outputs-configure-auth] of the input/output reference.

### [configure-authentication]:
{% code_snippet 'examples', 'auth-configuration' %}

### [configure-ldap-authentication]:
{% code_snippet 'examples', 'ldap-auth-configuration' %}

### [configure-saml-authentication]:
{% code_snippet 'examples', 'saml-auth-configuration' %}

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
