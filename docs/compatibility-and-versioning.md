This topic describes Platform Automation Toolkit dependencies and semantic versioning.

## External Dependencies
Platform Automation Toolkit is designed to work with these dependencies.

<style>
    sup {
        background-color: white;
    }
</style>

<table>
<thead>
    <tr>
        <th>Platform Automation Toolkit</th>
        <th>Concourse</th>
        <th>Ops Manager</th>
        <th>Pivnet Resource</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>v5.0.0</td>
        <td><a href="https://concourse-ci.org"><code>v5.0.0+</code></a><sup>1</sup></td>
        <td><a href="https://network.pivotal.io/products/ops-manager/">v2.3+</a></td>
        <td><a href="https://github.com/pivotal-cf/pivnet-resource">v0.31.15</a></td>
    </tr>
    <tr>
        <td>v4.3.0</td>
        <td><a href="https://concourse-ci.org"><code>v4.0.0+</code></a><sup>1</sup></td>
        <td><a href="https://network.pivotal.io/products/ops-manager/">v2.3+</a></td>
        <td><a href="https://github.com/pivotal-cf/pivnet-resource">v0.31.15</a></td>
    </tr>
    <tr>
        <td>v4.2.0</td>
        <td><a href="https://concourse-ci.org"><code>v4.0.0+</code></a></td>
        <td><a href="https://network.pivotal.io/products/ops-manager/">v2.3+</a></td>
        <td><a href="https://github.com/pivotal-cf/pivnet-resource">v0.31.15</a></td>
    </tr>
    <tr>
        <td>v4.1.0</td>
        <td><a href="https://concourse-ci.org"><code>v4.0.0+</code></a></td>
        <td><a href="https://network.pivotal.io/products/ops-manager/">v2.3+</a></td>
        <td><a href="https://github.com/pivotal-cf/pivnet-resource">v0.31.15</a></td>
    </tr>
    <tr>
        <td>v4.0.0</td>
        <td><a href="https://concourse-ci.org"><code>v4.0.0+</code></a></td>
        <td><a href="https://network.pivotal.io/products/ops-manager/">v2.3+</a></td>
        <td><a href="https://github.com/pivotal-cf/pivnet-resource">v0.31.15</a></td>
    </tr>
</tbody>
</table>

<sup>1</sup> 
    [`prepare-tasks-with-secrets`][prepare-tasks-with-secrets] replaces [`credhub-interpolate`][credhub-interpolate] in Concourse 5.x+ _only_. 
    If using Concourse 4.x, continue using `credhub-interpolate`.
    If using Concourse 5.x+, it is strongly recommended to switch to `prepare-tasks-with-secrets`.
    For more information about secrets handling, reference the [Secrets Handling Page][secrets-handling].

{% include "./.opsman_filename_change_note.md" %}

## Semantic Versioning
This product uses [semantic versioning][semver] 2.0.0
to describe the impact of changes to our concourse tasks. In order to take advantage of semantic versioning, we must declare an API.

The following are considered part of our API:

- Our concourse tasks':

    - inputs and outputs (including the format/required information in config files)
    - specified parameters
    - intended and specified functionality

    These are all documented for each task within the task files themselves.

- The minimum compatible version
  of Concourse and Ops Manager
  are part of the API,
  and are specified [here][external-deps].

- The presence of the following binaries on the _combined image_:

    - bash 
    - build-essential 
    - curl 
    - gettext 
    - git 
    - netcat-openbsd 
    - python3-pip 
    - python3-setuptools 
    - rsync 
    - ssh 
    - unzip 
    - zip 
    - gcloud
    - python-openstackclient
    - awscli
    - azure-cli
    - bbr-cli
    - bosh-cli
    - credhub-cli
    - govc
    - isolation-segment-replicator
    - om
    - p-automator
    - winfs-injector
    
- The patterns necessary to specify our files on Tanzu Network:
  We will consider it a breaking change
  if any of the following glob patterns for the Platform Automation Toolkit image and tasks
  fail to return a single match
  when used with the `pivnet-resource` and/or `download-product` task:
    - `platform-automation-image-*.tgz`             # all IaaSes image
    - `vsphere-platform-automation-image-*.tar.gz`  # vSphere only image
    - `platform-automation-tasks-*.zip`             # tasks


The following are NOT covered:

- the `om` command line tool
- the `p-automator` command line tool
- the dependencies on the image intended to be used with our tasks
- non-specified parameters (for instance, any env var used by a CLI we call
  but not specified as a parameter on the task)
- properties specific to particular product or ops manager versions in config files
  (which are governed by the product being configured, not our tooling)
- Versions of the included binaries. 
  The _presence_ of those binaries are guaranteed, but the _versions_ are not.

In general, if we make any change 
that we anticipate could not be consumed without manual changes,
we consider it a breaking change, and increment the major version accordingly.

This assumes that the required image can be made automatically available;
each version of our tasks is designed for and tested with
_only_ the version of the image that shipped with it.

If we accidentally violate our semver,
we will publish an additional version addressing the problem.
In some cases, that may mean releasing the same software with a corrected version,
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
