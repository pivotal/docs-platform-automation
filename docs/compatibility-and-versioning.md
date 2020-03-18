This topic describes Platform Automation Toolkit dependencies and semantic versioning.

## External Dependencies
Platform Automation is designed to work with these dependencies.

<table>
<thead>
    <tr>
        <th>Platform Automation</th>
        <th>Concourse</th>
        <th>Ops Manager</th>
        <th>Pivnet Resource</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>v4.2.0</td>
        <td><a href="https://concourse-ci.org"><code>v3.14.1+</a></td>
        <td><a href="https://network.pivotal.io/products/ops-manager/">v2.3+</a></td>
        <td><a href="https://github.com/pivotal-cf/pivnet-resource">v0.31.15</a></td>
    </tr>
    <tr>
        <td>v4.1.0</td>
        <td><a href="https://concourse-ci.org"><code>v3.14.1+</a></td>
        <td><a href="https://network.pivotal.io/products/ops-manager/">v2.3+</a></td>
        <td><a href="https://github.com/pivotal-cf/pivnet-resource">v0.31.15</a></td>
    </tr>
    <tr>
        <td>v4.0.0</td>
        <td><a href="https://concourse-ci.org"><code>v3.14.1+</a></td>
        <td><a href="https://network.pivotal.io/products/ops-manager/">v2.3+</a></td>
        <td><a href="https://github.com/pivotal-cf/pivnet-resource">v0.31.15</a></td>
    </tr>
    <tr>
        <td>v3.0.0</td>
        <td><a href="https://concourse-ci.org"><code>v3.14.1+</a></td>
        <td><a href="https://network.pivotal.io/products/ops-manager/">v2.3+</a></td>
        <td><a href="https://github.com/pivotal-cf/pivnet-resource">v0.31.15</a></td>
    </tr>
</tbody>
</table>

{% include "./.opsman_filename_change_note.md" %}

## Semantic Versioning
This product uses [semantic versioning][semver] 2.0.0
to describe the impact of changes to our concourse tasks. In order to take advantage of semantic versioning, we must declare an API.

The following are considered part of our API:

Our concourse tasks':

- inputs and outputs (including the format/required information in config files)
- specified parameters
- intended and specified functionality

These are all documented for each task within the task files themselves.

Additionally, the minimum compatible version
of Concourse and Ops Manager
are part of the API,
and are specified [here][external-deps].

The following are NOT covered:

- the `om` command line tool
- the `p-automator` command line tool
- the dependencies on the image intended to be used with our tasks
- non-specified parameters (for instance, any env var used by a CLI we call
  but not specified as a parameter on the task)
- properties specific to particular product or ops manager versions in config files
  (which are governed by the product being configured, not our tooling)

In general, if we make any change that we anticipate could not be consumed
automatically,
without manual changes,
by all users of our Concourse tasks,
we consider it a breaking change, and increment the major version accordingly.

This assumes that the required image can be made automatically available;
each version of our tasks is designed for and tested with
_only_ the version of the image that shipped with it.

If we accidentally violate our semver,
we will publish an additional version addressing the problem.
In some cases, that may mean releasing ths same software with a corrected version,
and shipping a new patch version identical to the version prior to the violation.
In others, it may mean releasing an additional patch version
which reverts an unintentional breaking change.

This should make it safe to automatically consume our release.
Patch releases should be very safe to automatically update to.
Minor versions should be safe,
but it can be more difficult to anticipate the effect of new features,
so this is slightly riskier.
Major versions should be expected to break
for at least some users when consumed automatically.
Automatic consumption of major versions should be limited
to test/staging environments
intended to endure and detect such breakage.


{% include ".internal_link_url.md" %}
{% include ".external_link_url.md" %}

[semver]: https://semver.org
[external-deps]: #external-dependencies
