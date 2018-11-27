## Compatibility and Dependencies

**External dependencies**

We have tested Platform Automation with these dependencies.

<table>
<thead>
    <tr>
        <th>Platform Automation</th>
        <th>Concourse</th>
        <th>OpsManager</th>
        <th>Pivnet Resource</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>latest version</td>
        <td><a href="https://concourse-ci.org"><code>v3.14.1+</a></td>
        <td><a href="https://network.pivotal.io/products/ops-manager/">v2.1+</a></td>
        <td><a href="https://github.com/pivotal-cf/pivnet-resource">v0.31.15</a></td>
    </tr>
</tbody>
</table>

**Docker Image dependencies**

These dependencies are installed on the docker image distributed on Pivnet.
The IaaS CLIs are used by and tested with `p-automator`,
and `om` is invoked directly in many tasks.

<table>
<thead>
    <tr>
        <th>p-automator</th>
        <th>om</th>
        <th>gcloud</th>
        <th>az</th>
        <th>openstack</th>
        <th>govc</th>
    </tr>
</thead>
<tbody>
    <tr>
        <td>latest version</td>
        <td><a href="https://github.com/pivotal-cf/om">v0.44.0+</a></td>
        <td><a href="https://cloud.google.com/sdk/gcloud/">v225.0.0</a></td>
        <td><a href="https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest/">v2.0.50</a></td>
        <td><a href="https://docs.openstack.org/python-openstackclient/">v3.17.0</a></td>
        <td><a href="https://github.com/vmware/govmomi/releases">v0.19.0</a></td>
    </tr>
</tbody>
</table>

{% include ".internal_link_url.md" %}
{% include ".external_link_url.md" %}
