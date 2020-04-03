# Configuration Management Strategies

When building pipelines,
there are many possible strategies
for structuring your configuration in source control.
No single method can cover all situations.
After reading this document,
we hope you feel equipped to select an approach.

## Single Repository for Each Foundation

This is the simplest thing that could possibly work.
It's the default assumed in all our examples,
unless we've articulated a specific reason to choose a different approach.
It entails using a single Git repository for each foundation.

Tracking foundation changes are simple,
getting started is easy,
duplicating foundations is simply a matter of cloning a repository,
and configuration files are not difficult to understand.

This is the strategy used throughout the
[Install Ops Man How to Guide][install-how-to] and the
[Upgrading an Existing Ops Manager How to Guide][upgrade-how-to].

Let's examine an example configuration repository
that uses the "Single Repository for each Foundation" pattern:

```
├── auth.yml
├── pas.yml
├── director.yml
├── download-opsman.yml
├── download-product-configs
│   ├── healthwatch.yml
│   ├── opsman.yml
│   ├── pas-windows.yml
│   ├── pas.yml
│   └── telemetry.yml
├── env.yml
├── healthwatch.yml
├── opsman.yml
└── pas-windows.yml
```

Notice that there is only one subdirectory
and that all other files are at the repositories base directory.
_This minimizes parameter mapping in the platform-automation tasks_.
For example, in the [`configure-director`][configure-director]
step:

{% code_snippet 'examples', 'configure-director-usage' %}

we map the config files 
to the expected input named `env` of the `configure-director` task.
Because the `configure-director` task's default `ENV` parameter is `env.yml`,
it automatically uses the `env.yml` file in our configuration repo. 
We do not need to explicitly name the `ENV` parameter for the task.
This also works for `director.yml`.

For reference, here is the `configure-director` task:

{% code_snippet 'tasks', 'configure-director' %}

## Multiple Foundations with one Repository

Multiple foundations may use a single Git configuration source
but have different variables loaded 
from a foundation specific vars file, Credhub, Git repository, etc.
This approach is very similar to the Single Repository for Each Foundation
described above,
except that variables are loaded in from external sources.

The variable source may be loaded in a number of ways. For example,
it may be loaded from a separate foundation specific Git repository,
a foundation specific subdirectory in the configuration source, 
or even a foundation specific vars file found in the base Git configuration.

This strategy can reduce the number of overall configuration files
and configuration repositories in play,
and can reduce foundation drift (as the basic configuration is being pulled 
from a single master source).
However,
configuration management and secrets handling
can quickly become more challenging.

**This is the strategy used in our [Reference Pipeline][reference-pipeline]**

For an example repo structure using this strategy,
see the [config repo][reference-pipeline-config]
used by the [Reference Pipeline][reference-pipeline] and the [Resources Pipeline][reference-resources]

As our How To Guides expand,
we will explore this strategy further.
Stay tuned for more.

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}