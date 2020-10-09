# Maintainer's Guide Notes

It is our intention to centralize our notes
about how we maintain and release Platform Automation Toolkit here.
Keeping in mind that this is a _public repository_,
so secrets and some details will necessarily be stored
in other systems,
though their existence and location should be documented here.

Many of these links require VMware VPN access or other credentials;
these instructions are public as an implementation detail,
and are not intended to be useful to the public.

## CVEs and Patching Steps
1. Update the release notes for patching CVEs (and/or other security/package updates).
   This should be updated in `docs-platform-automation/ci/patch-notes/cve-patch-notes.md`
   The bug fixes for the last release should be already populated.
   _Replace the existing release notes with the release notes for the newest patch._
   
   **NOTE** Any release notes in `cve-patch-notes.md` will be applied to _all supported versions_.<br />
   To add bug fixes to a specific version, edit the `X.X-patch-notes.md` file instead. 
1. Commit and push the changes
1. Trigger the `build-all-versions-image` job in the [`bump`](https://platform-automation.ci.cf-app.com/teams/main/pipelines/bump) pipeline

   This will trigger the CVE/patch process.
   To validate the appropriate CVEs were updated in supported versions,
   wait until the `update-vX.X` job has completed,
   then download the `image-receipt-X.X.X` from AWS S3
   (this link is also be available in the release notes for each version).

Note: if,for some reason, any `update-vX.X` job fails,
the job can be re-run and will not re-generate release notes.
However, the release date of the job
will be whatever the date of the first run for the patch was.
The task that generates the release notes for each minor/major version
is called `create-release-notes-for-patch`.
This task exists in all `update-vX.X` jobs.

Once the job is completed, you're done!
The job pushes each patch directly to Tanzunet for all users.
Check that the patches are present as expected. 

### Updating the Release Notes Manually
There is an easy (manual) way to undo the docs created for CVE patching.
This could be due to:
- failure to update the `cve-patch-notes.md` before creating patch,
  so the release notes are wrong
- there were additional bug fixes that were left out
- some other reason

The following steps are a manual process to "revert"
the generated release notes and re-create them manually.<br />
**Note:** if due to a failed build, you _must_ stop before the last step.
CI will fail if the version already exists.
1. `git clone https://github.com/pivotal/platform-automation-ci` (private)
1. git pull in `docs-platform-automation`
1. `git submodule update --init --recursive` in `docs-platform-automation`
1. make a list of each version that will be patched in x.x.x format
  (this is the most recent version of each supported minor).
1. manually remove the entirety of each supported minor section from `docs-platform-automation/docs/release-notes.md`
1. commit and push
1. run the following command to remove those sections from the previous branches

   ```bash
   go run platform-automation-ci/scripts/generate-release-notes/generate-release-notes.go \
   --docs-dir /path/to/docs-platform-automation
   ```

1. If there are bug fixes for specific versions, do not create release notes for all versions (a.),
   but instead create the release notes for each version individually(b.).
   
   **a.** all versions
   
     with an updated `docs-platform-automation/ci/cve-patch-notes/cve-patch-notes.md`,
     and the list of each supported full patch version,
     run the following command:

     ```bash
     go run platform-automation-ci/scripts/generate-release-notes/generate-release-notes.go \
     --docs-dir /path/to/docs-platform-automation \
     --cve-patch-notes-path /path/to/docs-platform-automation/ci/cve-patch-notes/cve-patch-notes.md \
     --cve-patch-versions x.x.x \
     --cve-patch-versions y.y.y \
     --cve-patch-versions z.z.z
     ```

     This command will generate a new section for each patch version provided
     with the current date and the data written in `cve-patch-notes.md`.
     The changes are pushed, and develop is re-checked out,
     so no more manual work is necessary.

   **b.** individual versions
   
     with an updated `docs-platform-automation/ci/patch-notes/cve-patch-notes.md`,
     and an updated `docs-platform-automation/ci/patch-notes/X.X-patch-notes.md`,
     and a _specific_ patch version,
     run the following command:
     
     ```bash
     go run platform-automation-ci/scripts/generate-release-notes/generate-release-notes.go \
     --docs-dir /path/to/docs-platform-automation \
     --cve-patch-notes-path /path/to/docs-platform-automation/ci/cve-patch-notes/cve-patch-notes.md \
     --cve-patch-notes-path /path/to/docs-platform-automation/ci/cve-patch-notes/X.X-patch-notes.md \
     --cve-patch-versions X.X.X 
     ```

### What if I Need to Add Release Notes for a Feature or Breaking Change to a Patch Version?
Don't. Revert any such changes to those patch versions.

Platform Automation is strictly [semvered](https://semver.org/)
with an API defined in our [docs](https://docs-pcf-staging.cfapps.io/platform-automation/develop/compatibility-and-versioning.html#semantic-versioning).

Patching of this product should _never_ include features or breaking changes.

In the event that we _do_ release such changes
despite our best intentions and efforts,
we should release a subsequent patch that documents and reverts the changes.

## ODP and OSL
In the bump pipeline, the [`test-image-dependency-stability`](https://platform-automation.ci.cf-app.com/teams/main/pipelines/bump/jobs/test-image-dependency-stability/builds/100) job
validates that our packages have not changed.
This is because we do not have to request a new OSL if there are no new packages.

The automation in the pipelines will take files from our s3 bucket: `platform-automation-release-candidate`.
If a new OSL/ODP is required, simply upload the new file(s) to s3 and CI will handle the rest.

### OSL
This is a fully manual process. Please reference [VMware's guides](https://osm.eng.vmware.com/doc/) for creating new OSLs.
OSLs can be downloaded directly from the OSM tool, and subsequently uploaded to s3.

### ODP
The ODP tool is completely manual at the moment.
Kris's instructions: https://confluence.eng.vmware.com/display/CNA/ODP+for+Pivotal+Alumni+-+A+Crash+Course
(Requires VMware VPN).
The super basic generic walkthrough (check Kris' instructions for better detail):
1. download the osstpmgt.csv file that contains dep #s from the OSM tool
1. download and create osstpclients docker image
1. mount workspace and open docker image
1. follow Kris's instructions to get ids from csv
1. follow Kris's instructions to run tool
1. create BUILD.txt and INSTALL.txt in the created directory
1. zip the ODP directory
1. upload ODP to s3

#### GOTCHAS FROM PAST ODPs
ERROR from the osstpclients tool:
```
Creating/updating the skeleton directory "./VMware-tanzu-platform-automation-toolkit-5.0.0-ODP"
Processing 1 command line defined packages
[otc-00009]: Warning: No sources available for the package "ct-tracker-ubuntu - none" (#750049)
Successfully exported 0 of 1 packages
The packages that could not be created are:
    #2456833 Other "ct-tracker-ubuntu - none"
```
ANALYSIS:
 the ODP tool did not like the `ct-tracker-ubuntu` package.
    1. We had to go down the "clone chain"(`Cloned from 2361434 / View clone chain` if in OSM) until there is no more clone chain.
    1. Click "View" on the master package: `Master Package RESOLVED / APPROVED (View)`
    1. Click "View list of Packages": `Use Packages View list of Use Packages (133)`
    1. export to CSV as defined in Kris's instructions
    1. add the other IDS from PAT to the CSV
    1. complete Kris's instructions as normal

#### BUILD.txt and INSTALL.txt
If any dependencies require SBR,
add the following 2 files into the generated folder
before zipping the directory:

BUILD.txt
```
# install build dependencies
apt-get update && apt-get install build-essential fakeroot devscripts equivs

# unpackage and enter source code directory
tar -xzf <package-version>.tar.gz
cd <package-version>
tar -xf <package-version>.tar.xz

# if there is a <package-version>.debian.tar.xz
tar -xf <package-version>.debian.tar.xz
mv debian <package-version>

# once you have the debian directory, move inside
cd <package-version>

# apply any necessary patches
patch -p1 < SomePackagePatch.patch

# install package dependencies and create package
mk-build-deps

# move final package
mv <package-version>.deb ../..
```

INSTALL.txt
```
# assuming you have followed the BUILD.txt instruction to build
dpkg -i <package-version>.deb
```

## [Reference Pipeline](https://github.com/pivotal/docs-platform-automation-reference-pipeline-config) Maintenance
The reference pipeline (not "example pipeline") from our [docs](https://docs-pcf-staging.cfapps.io/platform-automation/develop/pipelines/multiple-products.html)
is fully tested in [CI](https://platform-automation.ci.cf-app.com/teams/main/pipelines/reference-pipeline).
It is currently deployed on GCP,
though history of the repo will reveal that it was previously deployed on vSphere.

When making any new features for the product, the reference pipeline should be run,
and should be completely green before release. The [`additional-task-testing`](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/jobs/additional-task-testing/builds/170) job
relies on the reference-pipeline being successfully up and deployed.
This ci pipeline task _is explicitly_ a release blocker, while the reference pipeline is not explicitly a blocker.

The reference pipeline exists in the [docs-platform-automation-reference-pipeline-config](https://github.com/pivotal/docs-platform-automation-reference-pipeline-config) repo.
The repo is organized to represent a [multi-foundation configuration structure](https://docs-pcf-staging.cfapps.io/platform-automation/develop/pipeline-design/configuration-management-strategies.html#multiple-foundations-with-one-repository).
The reference pipeline is the `sandbox` directory in that repo. 

`auth.yml` and `env.yml` are shared between foundations.
Values for these files are set on a per-foundation/per-pipeline basis,
and the values are stored in Credhub.

Terraform files for the reference pipeline can be found in the [deployments](https://github.com/pivotal/platform-automation-deployments) repo.
The deployments repo also contains all relevant terraform/vars for all of our ci test pipelines.
The reference pipeline is saved in the `reference-gcp` directory.

### Recreating the reference pipeline

If the reference pipeline needs to recreated for any reason,
the following steps must be executed.

1. Run the [`reference-gcp-delete-infrastructure`](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/jobs/reference-gcp-delete-infrastructure) job.
   This job will attempt to, in the following order: 
   * delete the deployment
   * delete the terraform infrastructure
   * use [leftovers](https://github.com/genevieve/leftovers) to cleanup all extra resources with the `reference-gcp` tag

1. Recreate the terraform infrastructure using the instructions in platform-automation-deployments [`reference-gcp` README](https://github.com/pivotal/platform-automation-deployments/blob/main/reference-gcp/README.md)
1. Commit the terraform.tfstate
1. (Optional) `platform-automation-deployments/reference-gcp/terraform-outputs.json` is present for convenience, and was crafted by executing the following commands inside the `reference-gcp` directory:

   ```
   terraform output stable_config_opsmanager > terraform-outputs.yml
   terraform output stable_config_pas >> terraform-outputs.yml
   terraform output stable_config_pks >> terraform-outputs.yml
   ```
       
1. Recreate the vars files for the reference pipeline by extracting the terraform vars:
   Vars files for the reference pipeline can be found in `docs-platform-automation-reference-pipeline-config/foundations/sandbox/vars`.
   To update these files, from inside the platform-automation-deployments/reference-gcp directory:

   ```bash
   terraform output stable_config_opsmanager > ~/workspace/docs-platform-automation-reference-pipeline-config/foundations/sandbox/vars/director.yml
   terraform output stable_config_pas > ~/workspace/docs-platform-automation-reference-pipeline-config/foundations/sandbox/vars/tas.yml
   terraform output stable_config_pks > ~/workspace/docs-platform-automation-reference-pipeline-config/foundations/sandbox/vars/pks.yml
   ```

1. The terraform outputs contain secrets. 
   **_REMEMBER_**: `docs-platform-automation-reference-pipeline-config` is a public repo.
   _Do not store secrets in a public repo_
   
   Update the following values in [`export.yml`](https://github.com/pivotal/platform-automation-deployments/blob/main/concourse-credhub/export.yml) using values from the terraform outputs:

   * /concourse/main/reference-pipeline/service_account_key
   * /concourse/main/reference-pipeline/ops_manager_service_account_key
   * /concourse/main/reference-pipeline/ssl_certificate
   * /concourse/main/reference-pipeline/ssl_private_key
   * /concourse/main/reference-pipeline/ops_manager_ssh_private_key
   * /concourse/main/reference-pipeline/ops_manager_ssh_public_key
       
   Remove the above secrets from `vars/director.yml`, `vars/tas.yml`, `vars/pks.yml`
   Also update any other secrets from the terraform outputs in the `export.yml`

1. To store/edit values in Credhub, export the vars from the `.envrc` in `platform-automation-deployments/concourse-credhub`.
   You can now access Credhub as normal. Run:
    ```bash
    credhub import -f export.yml
    ```

1. Commit all changes
1. Update the [`state-sandbox.yml`](https://ref-pipeline-state.s3-us-west-2.amazonaws.com/state-sandbox.yml) to be empty-file.
1. Delete the `reference-pipeline`: (this is done to reset any pipeline triggers)
   ```
   fly -t ci dp -p reference-pipeline
   ```

1. Refly the reference pipeline
   ```
   cd ~/workspace/docs-platform-automation-reference-pipeline-config
   ./scripts/update-reference-pipeline.sh
   ```
   
1. Rerun the reference-pipeline from the beginning.
   The pipeline triggers should function as normal,
   and you should expect a new reference pipeline env in approximately 2-3 hours.
   We recommend checking in on the pipeline every now and then
   to validate it is running smoothly.
    

#### Create a cluster

We need to create a PKS cluster because we test the `backup-tkgi` task in [additional task testing.](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/jobs/additional-task-testing/builds/185)

**_This has been automated by the [create-pks-cluster-in-reference-pipeline task](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/jobs/create-pks-cluster-in-reference-pipeline/builds/24)._**

The task will perform the following steps, documented here for the purposes of manual creation should the need arise:

1. Get the Private SSH key for the Ops Manager VM, this will be available in the terraform outputs. 
1. Create a user that will be the owner of the cluster.
    ```bash
    ssh -i /tmp/key ubuntu@opsmanager.reference-gcp.gcp.platform-automation.cf-app.com
    uaac target https://api.pks.reference-gcp.gcp.platform-automation.cf-app.com:8443 --ca-cert /var/tempest/workspaces/default/root_ca_certificate
    uaac token client get admin -s <uaa admin management secret>
    uaac user add platform-automation --emails platform-automation@example.com -p <super-secret-password>
    uaac member add pks.clusters.admin platform-automation
    ```

1. Create a PKS cluster
    ```bash
    ./pks login -a api.pks.reference-gcp.gcp.platform-automation.cf-app.com -u platform-automation -p <super-secret-password> --skip-ssl-verification
    ./pks create-cluster my-cluster --plan small --external-hostname example.hostname
    watch ./pks cluster my-cluster # eventually this will have a status of "complete"
    ```

1. Wait up to 30 minutes for the cluster to be created.

## Docs Maintenance
Most of the docs are found here in this `docs-platform-automation` repo.
Locked versions for the docs are for every minor version released.

The docs are built using `mkdocs` (see [README](https://github.com/pivotal/docs-platform-automation/blob/develop/README.md) for build instructions). 
The docs make use of the [`mkdocs-pivotal-theme`](https://github.com/pivotal/mkdocs-pivotal-theme) for
the vmware-common formatting/css/etc for the docs site. 

### Link Linter
Inside of `mkdocs-pivotal-theme`, there is a helpful tool
that we use to make sure the links across all versions
are valid and working.
In the [ci](https://platform-automation.ci.cf-app.com/), this linter is used in the `deploy-to-staging` job in the `docs` pipeline.

#### Broken Links
The link linter is very aggressive.
Sometimes the errors from the link linter are benign, and require a re-run:
```
https://docs-pcf-staging.cfapps.io/platform-automation/v5.0/concepts/stemcell-handling.html
	timeout	https://bosh.io/docs/stemcell/
```

Others require a little more manual work:
```
https://docs-pcf-staging.cfapps.io/platform-automation/v5.0/release-notes.html
	403	https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.5
# REQUIRED FIX: download the 5.0.5 image,
# run dpkg -l > image-receipt-5.0.5,
# then upload to the platform-automation-release-candidate bucket in S3
```

Another example:
```
# From https://platform-automation.ci.cf-app.com/teams/main/pipelines/docs/jobs/deploy-to-staging/builds/1964
https://docs-pcf-staging.cfapps.io/platform-automation/v4.0/index.html
	404	http://docs.pivotal.io/platform/customizing/pcf-interface.html
```
The steps to fix this link were:
1. search for the link in `docs-platform-automation/docs/.external_link_url.md`
1. use the same url for a version of Ops Manager known to have worked with the link
   (in this case, we navigated to: http://docs.pivotal.io/platform/2-7/customizing/pcf-interface.html)
1. switch the docs branch to the most recent version
1. remove the version information from the new url, and update it in the `.external_link_url` file
   (in this case, we used: https://docs.pivotal.io/ops-manager/pcf-interface.html)
1. Commit changes, push, and allow the link linter to run again

#### "undefined code blocks"
The Link Linter will also check to make sure that there are no code blocks (` ``` ``` `)
in the documentation itself.
This is usually a sign that we are referencing a code snippet
that the docs don't know about,
or we updated the docs in that area in a way that made it so
mkdocs could not properly parse the code block.

In `docs-platform-automation/mkdocs.yml`, you will find the following:
```
- markdown-code-excerpt:
    sections:
      tasks: "../platform-automation"
      examples: "./docs/examples"
      reference: "./external/docs-platform-automation-reference-pipeline-config"
      paving: "./external/paving"
```
with this defined, we can reference any snippets in .yml from the listed repos.

The format for a snippet is (let's assume this is in `examples`):
```yaml
# code_snippet awesome-snippet-name start yaml
some-snippet
# code_snippet awesome-snippet-name end
```

This is used in the docs like so:
```
---excerpt--- "examples/awesome-snippet-name"
```

As long as the snippet is available, mkdocs will render it in the docs. 
If it is not available, it will be rendered as written above.

Because our docs take advantage of mkdocs tabbing (`=== "Tab Name"`),
the display often comes out incorrect with the code block used to format the snippet.
The link linter returns an error like the following if this happens:
```
Running a check for undefined code blocks (```)...
./platform-automation/v4.4/how-to-guides/upgrade-existing-opsman.html:2281 <p>``` yaml
./platform-automation/v4.4/how-to-guides/upgrade-existing-opsman.html:2287     ```</p>
./platform-automation/v4.4/how-to-guides/upgrade-existing-opsman.html:2289 <p>``` yaml
./platform-automation/v4.4/how-to-guides/upgrade-existing-opsman.html:2295     ```</p>
./platform-automation/v4.4/how-to-guides/upgrade-existing-opsman.html:2297 <p>``` yaml
./platform-automation/v4.4/how-to-guides/upgrade-existing-opsman.html:2303     ```</p>
./platform-automation/v4.4/how-to-guides/upgrade-existing-opsman.html:2305 <p>``` yaml
./platform-automation/v4.4/how-to-guides/upgrade-existing-opsman.html:2311     ```</p>
./platform-automation/v4.4/how-to-guides/upgrade-existing-opsman.html:2313 <p>``` yaml
./platform-automation/v4.4/how-to-guides/upgrade-existing-opsman.html:2319     ```</p>
Generated HTML contains undefined code blocks!
```

To fix this problem, if requires you to go into the `.md` of the effected file
and do a syntax check of the affected area.

#### "unidentified reference-style links"
The links in the docs are kept in `docs-platform-automation/docs/.internal_link_url.md` and `docs-platform-automation/docs/.external_link_url.md`
for easy updating and reference. 

When we use the links elsewhere in the docs, instead of using the `[link-name](link-url)` format,
we use [link-name][link-reference].

The link linter checks to make sure these custom references all go somewhere.
If they do no, you will get an error like the following:
```
Running a check for undefined reference-style links...
./platform-automation/develop/release-notes.html:6961 <li>[<code>pending-changes</code>][pending-changes] would always fail if installation incomplete, product unconfigured, or stemcell missing
./platform-automation/v4.2/release-notes.html:3928 <li>[<code>pending-changes</code>][pending-changes] would always fail if installation incomplete, product unconfigured, or stemcell missing
./platform-automation/v4.3/release-notes.html:5441 <li>[<code>pending-changes</code>][pending-changes] would always fail if installation incomplete, product unconfigured, or stemcell missing
./platform-automation/v4.4/release-notes.html:6361 <li>[<code>pending-changes</code>][pending-changes] would always fail if installation incomplete, product unconfigured, or stemcell missing
./platform-automation/v5.0/release-notes.html:6961 <li>[<code>pending-changes</code>][pending-changes] would always fail if installation incomplete, product unconfigured, or stemcell missing
Generated HTML contains undefined links!

# SOLUTION: add the missing link to .external_link_url or .internal_link_url
```
