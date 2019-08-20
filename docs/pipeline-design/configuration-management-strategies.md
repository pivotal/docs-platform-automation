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
It entails using a single git repository for each foundation.

Tracking foundation changes are simple,
getting started is easy,
duplicating foundations is simply a matter of cloning a repository,
and configuration files are not difficult to understand.

This is the strategy used throughout the
[Install Ops Man How to Guide][install-how-to] and the
[Upgrading an Existing Ops Manager How to Guide][upgrade-how-to].
This is also the strategy implicit in our PAS reference pipeline.

The [PAS reference pipeline][reference-pipeline]
is an example pipeline that can be used
as a reference for your own foundation.
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
│   └── pas.yml
├── env.yml
├── healthwatch.yml
├── opsman.yml
└── pas-windows.yml
```

Notice that there is only one subdirectory
and that all other files are at the repositories base directory.
_This minimizes parameter mapping in the platform-automation tasks_.
For example, in the [`configure-director`][configure-director]
step in the [reference pipeline][reference-pipeline]: 

{% code_snippet 'examples', 'configure-director-usage' %}

we map the interpolated config files 
to the expected input named `env` of the `configure-director` task.
`interpolated-creds` is the output of a `credhub-interpolate` step
whose input is a single foundation repo.
Because the `configure-director` task's default `ENV` parameter is `env.yml`,
it automatically uses the `env.yml` file in our configuration repo. 
We do not need to explicitly name the `ENV` parameter for the task.
This also works for `director.yml`.

For reference, here is the `configure-director` task:

{% code_snippet 'tasks', 'configure-director' %}

## Multiple Foundations with one Repository

Multiple foundations may use a single git configuration source
but have different variables loaded 
from a foundation specific vars file, credhub, git repository, etc. 
This approach is very similar to the Single Repository for Each Foundation
described above,
except that variables are loaded in from external sources.

The variable source may be loaded in a number of ways. For example,
it may be loaded from a separate foundation specific git repository,
a foundation specific subdirectory in the configuration source, 
or even a foundation specific vars file found in the base git configuration.

This strategy can reduce the number of overall configuration files
and configuration repositories in play,
and can reduce foundation drift (as the basic configuration is being pulled 
from a single master source).
However,
configuration management and secrets handling
can quickly become more challenging.

As our How To Guides expand,
we will explore this strategy further.
Stay tuned for more.

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}