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

## Platform Automation Github Repositories

* https://github.com/pivotal/docs-platform-automation
* https://github.com/pivotal/docs-platform-automation-reference-pipeline-config
* https://github.com/pivotal/platform-automation-deployments
* https://github.com/pivotal-cf/om
* https://github.com/pivotal/paving
* https://github.com/pivotal/mkdocs-pivotal-theme/
* https://github.com/pivotal/mkdocs-plugins

## CVEs and Patching Steps

[Platform Automation Toolkit](https://support.broadcom.com/group/ecx/productdownloads?subfamily=Platform%20Automation%20Toolkit) distributes three artifacts.
This includes a zip file of Concourse YAML tasks and two tarballs of container images, one smaller, vsphere-only image and one larger
image that can be used on all platforms.

The container image uses Ubuntu and its package manager to install most dependencies.
VMware (through Pivotal) has a support license, which provides timely security updates to these packages.

This document contains instructions of how the container is updated and released for security purposes:

1. [Verifying the Patch](#verifying-the-patch)
1. [Updating Patch Notes](#updating-patch-notes)
1. [Release the Patch](#release-the-patch)

### Verifying the Patch
If the container image does not have the correct version, the pipeline needs to be triggered to pull in the latest package.
1. Trigger the [`build-packages-image`](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/jobs/build-packages-image/builds/latest) job to start the container build process, which installs the latest packages.
   > **NOTE:** When this job finishes, it will trigger downstream `build-binaries-image-combined` and subsequent jobs.
1. When the `build-binaries-image-combined` is finished from its upstream trigger, reinspect the image receipt to confirm it was updated.

### Updating Patch Notes
1. Update the release notes with features, bug fixes, and CVEs.
   The release notes are found in: [`docs-platform-automation/ci/patch-notes`](https://github.com/pivotal/docs-platform-automation/tree/develop/ci/patch-notes)
   
   > **NOTE:** Release notes are _required_ for every release. If patch notes are omitted, CI will fail `create-release-notes-for-patch` job in `update-vX.X` jobs.

   > **NOTE:** Any release notes in `cve-patch-notes.md` will be applied to _all supported versions_.<br />
   To add bug fixes to a specific version, edit the `X.X-patch-notes.md` file instead. 
   
    ex.
   ```
   ### Bug Fixes
   - CVE update to container image.
   Resolves [USN 5133-1](https://ubuntu.com/security/notices/USN-5133-1),
   an issue related to ICU crashing
   ```
   If needed, see [Platform Automation Toolkit v5.0 Release Notes](https://docs.pivotal.io/platform-automation/v5.0/release-notes.html) for more examples.
1. Commit and push the changes

### Release the Patch
1. In the `ci` pipeline, make sure the build has passed all jobs that are not `promote-to-final`.
1. In the `patch-bump` group, trigger the [`bump-previous-versions-trigger`](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/jobs/bump-previous-versions-trigger/builds/29) job. The `get`s should have the same version as the `put`s from the [`build-binaries-image-combined`](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/jobs/build-binaries-image-combined/builds/latest) job.

   This will trigger the patch process.
   To validate the appropriate CVEs were updated in supported versions,
   wait until the `update-vX.X` job has completed,
   then download the `image-receipt-X.X.X` from AWS S3
   (this link is also be available in the release notes for each version).

   >**NOTE:** if any `update-vX.X` job fails during uploading to TanzuNet,
   delete the release and any files that were uploaded manually on the UI.
   Then re-run the job. The job will not re-generate release notes.
   However, the release date of the job will be whatever the date of the 
   first run for the patch was. The task that generates the release notes 
   for each minor/major version is called `create-release-notes-for-patch`.

1. The `update-vX.X` job pushes each patch release & its artifacts directly to S3 to be uploaded to RMT manually.
 - Eventually this will be done via automation, however it is a manual process as of the TanzuNet to RMT cutover.

### If Needed, Updating the Release Notes Manually
There is an easy (manual) way to undo the docs created for CVE patching.
This could be due to:
- failure to update the `cve-patch-notes.md` before creating patch,
  so the release notes are wrong
- there were additional bug fixes that were left out
- some other reason

The following steps are a manual process to "revert"
the generated release notes and re-create them manually.<br />
**NOTE:** if due to a failed build, you _must_ stop before the last step.
CI will fail if the version already exists.
1. `git clone https://github.com/pivotal/docs-platform-automation` 
1. `git submodule update --init --recursive` in `docs-platform-automation`
1. Make a list of each version that will be patched in x.x.x format
  (this is the most recent version of each supported minor).
1. Manually remove the entirety of each supported minor section from `docs-platform-automation/docs/release-notes.html.md.erb` & its respective branch:
   * `v5.2` [release notes](https://github.com/pivotal/docs-platform-automation/blob/v5.2/docs/release-notes.html.md.erb)
   * `v5.1` [release notes](https://github.com/pivotal/docs-platform-automation/blob/migration-v5.1/docs/release-notes.html.md.erb)
1. commit and push
1. run the following command to remove those sections from the previous branches

   ```bash
   go run docs-platform-automation/ci/scripts/generate-release-notes/generate-release-notes.go \
   --docs-dir docs-platform-automation/docs
   ```

1. If there are bug fixes for specific versions, do not create release notes for all versions (a.),
   but instead create the release notes for each version individually(b.).
   
   **a.** all versions
   
     with an updated `docs-platform-automation/ci/patch-notes/cve-patch-notes.md`,
     and the list of each supported full patch version,
     run the following command:

     ```bash
     go run docs-platform-automation/ci/scripts/generate-release-notes/generate-release-notes.go \
     --docs-dir docs-platform-automation/docs \
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
     go run docs-platform-automation/ci/scripts/generate-release-notes/generate-release-notes.go \
     --docs-dir /path/to/docs-platform-automation \
     --cve-patch-notes-path /path/to/docs-platform-automation/ci/cve-patch-notes/cve-patch-notes.md \
     --cve-patch-notes-path /path/to/docs-platform-automation/ci/cve-patch-notes/X.X-patch-notes.md \
     --cve-patch-versions X.X.X 
     ```

### What if I Need to Add Release Notes for a Feature or Breaking Change to a Patch Version?
Don't. Revert any such changes to those patch versions.

Platform Automation is strictly [semvered](https://semver.org/)
with an API defined in our [docs](https://docs-pcf-staging.tas.vmware.com/platform-automation/develop/compatibility-and-versioning.html#semantic-versioning).

Patching of this product should _never_ include features or breaking changes.

In the event that we _do_ release such changes
despite our best intentions and efforts,
we should release a subsequent patch that documents and reverts the changes.

## 📋 Process to obtain the ODP & OSL files from OSM using OSSPI Tooling 
When you commit a change to the Platform Automation Toolkit, propagate the committed change through the `ci` pipeline **until** you are ready to start the [bump-previous-versions-trigger job](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/jobs/bump-previous-versions-trigger/builds/latest), right before you plan to release the integrated change. The current process is very manual unfortunately, however, our instructions shall guide you through the process!

### When to do this process❓
If your changes have altered the packages being used in the [Platform Automation Image](dev.registry.pivotal.io/platform-automation/platform-automation-image) or in the [om-cli](), then you more than likely have to perform the OSM process. 
*  If you see changes to any go.mod files or any updates to the image itself, you should perform OSM. 
* 🤔 If you're unsure, it never hurts to run through our OSM process as it will report no changes if there are actually none.
* ⚠️ There should not regularly be changes to packages in Platform Automation! Any changes go to the Docker images go into _all_ released versions of Platform Automation Toolkit.

### Add 🆕 versions to BRM1
With BOSS Director being decommissioned, classic VMware teams moved to [BRM1](https://www.appsheet.com/start/24827112-c290-44b6-9b96-565d41f312f3). New Versions need to be added to BRM1 with some time allowed for them to sync to OSM.
* If you already have access, go to the next step. If you don't already have access, request it via [this form](https://forms.gle/AbTj3xz5uC7ZNjHa9). If that doesn't resolve, reach out to [GTO-Devops-BRM1-Assist Gchat](https://chat.google.com/room/AAAAw3fDxpo?cls=7). If all else fails, here's [other BRM1 FAQ](https://bsg-confluence.broadcom.net/display/DEVOPSRM/BRM1+-+Access) (Broadcom VPN Required). Access was granted within 1 hour of request.
* Go to [BRM1](https://www.appsheet.com/start/24827112-c290-44b6-9b96-565d41f312f3)
* Search for `Platform Automation Toolkit` in the Products, once it appears click the `>` on the right-side.
* There should be a `Related Releases` Section, click the `Add` button within it to add the new release version. Fill out the following:
   * **Product** -> `Platform Automation Toolkit`
   * **Version** -> `<New Release Version here>`
   * **Name** -> `Platform Automation Toolkit`
   * **Type** -> `<New Release Type here>`
   * **SLDC Phase** -> `Done`
   * **Product Manager** -> `rreza@vmware.com`
   * **Release Manager** -> `rreza@vmware.com`
   * **Engineering Lead** -> `rreza@vmware.com`
   * **General Availability Date** -> `<New Release GA Date here>`
* Click `Save` in the top-right corner, and th enew version should appear within the `Related Releases` for `Platform Automation Toolkit` now. 
* It will take some time for the version to sync to OSM. 
   * The addition of Platform Automation Toolkit versions previously propogated to OSM in < 4 hours.
   * **If this is an urgent release** you can simply proceed and update the version in line 3 of the OSL file later.


### 🛠️ OSSPI Pipeline Time 

Run the [OSM Job](https://runway-ci.eng.vmware.com/teams/ppe-platform-automation/pipelines/osspi/jobs/osm/builds/latest).

The scans are going to run the `run-osspi-source` & `run-osspi-docker` tasks from [Tony Wong's norsk-to-osspi tasks](https://gitlab.eng.vmware.com/source-insight-tooling/norsk-to-osspi/-/tree/main/tasks/osspi). These tasks will scan the main branches of `om-cli` & our Platform Automation Image for changes to report to OSM for compliance. The results will upload using [Ryan Hall's](ryan.hall@broadcom.com) API key for the OSM platform. Once the jobs are all green in the OSSPI Pipeline, the scans should be submitted to the `latest` version of the `platform-automation` release, which should be [here](https://osm.eng.vmware.com/oss/#/release/64167). The `latest` version acts as an inventory for the latest versions of these codebases. Once the OSM job has completed, verify the scans are uploaded and resolved. Get to the release by doing the following:

* Go to [OSM Releases](https://osm.eng.vmware.com/oss/#/release).
* Filter by **Release Name** of `platform-automation`.
* Click on the `latest` [version](https://osm.eng.vmware.com/oss/#/release/64167)
* You should see a link to `View all open source packages in this release`
* All the release's packages should in an `APPROVED` and/or `RESOLVED` state. 
  * If for some reason they are in error and you cannot determine why, reach out to [OSM Gchat](https://chat.google.com/room/AAAAHL9zc1k?cls=7) for assistance.

## Clone the packages

Once you have the new version of Platform Automation that you're going to release, click the `Add a Version / Clone Packages` button at the [top of the OSM Page](https://osm.eng.vmware.com/oss/#/version-cloning-request/new). Fill out the information for the new release(s):
* **OSM Release Name** -> `platform-automation`
* **New Version / Clone to Version** -> `<your new version here>`
* **First Milestone Release** -> `GA`

**Clone Packages / Release References** Section:

* **From Release Name** -> `platform-automation`
* **From Release Version** -> `latest`

This will fill out the managers, CC List, Licence Type, and some other fields. Continue to update the following:

* **CC List** -> `Add yourself and anyone else you want to involve in this process`
* **Distributed with VMware Release Name** -> `Platform Automation Toolkit`
* **Distributed with VMware Release Version** -> `<Version added to BRM1>` 
   * *You can update this later on line 3 in the OSL file if your new version hasn't propogated to OSM yet*
* **Requested Open Source License Date** -> `Today's date + 2 weeks, at least`
* Submit the request. OSPO will review this usually within a business day, then you can proceed once it's approved.

In the OSM Release page, there will be links to get what we need, OSL & ODP. 

### Download the new version OSL
* Go to [OSM Releases](https://osm.eng.vmware.com/oss/#/release).
* Filter by **Release Name** of `platform-automation`.
* Click on the new release version you uploaded for. 
* Scroll down to the `License File Review` section.
* Click the link to `View LFR Ticket`.
* Click `DEFINE PACKAGES LIST FOR OSL`, review and accept any prompts.
* For `Release`, click the dropdown and select the version you added to BRM1.
   * *You can update this later on line 3 in the OSL file if your new version hasn't propogated to OSM yet*
* For `Milestone`, click the dropdown and select `GA`.
* Click `GENERATE OSL`, review and accept any prompts.
* The file will take a moment to be generated.
* Once available, and after refreshing the release view, you will see the OSL `.zip` file in the `Generated OSLs` section. Download it and save it to upload it to S3 later.

### Download the new version ODP
* Go to [OSM Releases](https://osm.eng.vmware.com/oss/#/release).
* Filter by **Release Name** of `platform-automation`.
* Click on the new release version you uploaded for. 
* Click on the `ODP` tab.
* Click the button for `Generate ODP`, review and accept any prompts. This will take a moment.
* Once available, and after refreshing the release view, you will see a link in the `ODP Image` section of this view.
* Download the ODP, and save it to upload it to S3.

### Upload the OSL & ODP to S3 🪣

###TODO BELOW

* Go to [Cloudgate](https://console.cloudgate.vmware.com/ui/#/home?provider=aws) > **Tanzu TAS Operabiltiy** > `View Organization Accounts`
* Programatically, or through the web UI, get Power User access
* Once you're in, rename & move the OSL & ODP as described below:
* **OSL**:
  * The [OSL Resource](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/resources/osl) is looking for a file called `open_source_license_Platform_Automation_Toolkit_for_VMware_Tanzu_(.*)_GA.txt`, rename your OSL file to this convention.
  * `mv ~/path/to/downloaded/OSL.txt ~/open_source_license_Platform_Automation_Toolkit_for_VMware_Tanzu_<VERSION>_GA.txt`
  * `aws s3 cp ~/open_source_license_Platform_Automation_Toolkit_for_VMware_Tanzu_<VERSION>_GA.txt s3://platform-automation-release-candidate`
* **ODP**:
  * The [ODP Resource](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/resources/odp) is looking for a file called `VMware-Tanzu-platform-automation-toolkit-(.*)-ODP.tar.gz`, rename your ODP file to this convention.
  * `mv ~/path/to/downloaded/ODP.zip ~/VMware-Tanzu-platform-automation-toolkit-<VERSION>-ODP.tar.gz`
  * `aws s3 cp ~/VMware-Tanzu-platform-automation-toolkit-<VERSION>-ODP.tar.gz s3://platform-automation-release-candidate`
  * This file is > 1GB so the upload will take a moment.

### Resume the Release Process
With OSL & ODP where they need to be, you may now run the [bump-previous-versions-trigger](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/jobs/bump-previous-versions-trigger/builds/latest) job. Once the job completes, it will automatically start the following update jobs:

* [update-v5.1](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/jobs/update-v5.1/builds/latest)
* [update-v5.2](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/jobs/update-v5.2/builds/latest)

If these jobs successfully pull the OSL & ODP resources, then you have succesfully performed the OSSPI Process 🎉


## [Reference Pipeline](https://github.com/pivotal/docs-platform-automation-reference-pipeline-config) Maintenance
The reference pipeline (not "example pipeline") from our [docs](https://docs-pcf-staging.tas.vmware.com/platform-automation/develop/pipelines/multiple-products.html)
is fully tested in [CI](https://platform-automation.ci.cf-app.com/teams/main/pipelines/reference-pipeline).
It is currently deployed on GCP,
though history of the repo will reveal that it was previously deployed on vSphere.

When making any new features for the product, the reference pipeline should be run,
and should be completely green before release. The [`additional-task-testing`](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/jobs/additional-task-testing/builds/170) job
relies on the reference-pipeline being successfully up and deployed.
This ci pipeline task _is explicitly_ a release blocker, while the reference pipeline is not explicitly a blocker.

The reference pipeline exists in the [docs-platform-automation-reference-pipeline-config](https://github.com/pivotal/docs-platform-automation-reference-pipeline-config) repo.
The repo is organized to represent a [multi-foundation configuration structure](https://docs-pcf-staging.tas.vmware.com/platform-automation/develop/pipeline-design/configuration-management-strategies.html#multiple-foundations-with-one-repository).
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

1. Make sure you are using Terraform 1.0+
2. Recreate the terraform infrastructure using the instructions in platform-automation-deployments [`reference-gcp` README](https://github.com/pivotal/platform-automation-deployments/blob/main/reference-gcp/README.md)
3. Commit the terraform.tfstate
4. (Optional) `platform-automation-deployments/reference-gcp/terraform-outputs.json` is present for convenience, and was crafted by executing the following commands inside the `reference-gcp` directory:

   ```
   terraform output -json stable_config_opsmanager | jq -r > terraform-outputs.json
   terraform output -json stable_config_pas | jq -r >> terraform-outputs.json
   terraform output -json stable_config_pks | jq -r >> terraform-outputs.json
   ```
       
1. Recreate the vars files for the reference pipeline by extracting the terraform vars:
   Vars files for the reference pipeline can be found in `docs-platform-automation-reference-pipeline-config/foundations/sandbox/vars`.
   To update these files, from inside the platform-automation-deployments/reference-gcp directory:

   **DO NOT COMMIT THESE UPDATES YET!**

   ```bash
   terraform output -json stable_config_opsmanager | jq -r | jq > ~/workspace/docs-platform-automation-reference-pipeline-config/foundations/sandbox/vars/director.yml
   terraform output -json stable_config_pas | jq -r | jq  > ~/workspace/docs-platform-automation-reference-pipeline-config/foundations/sandbox/vars/tas.yml
   terraform output -json stable_config_pks | jq -r | jq  > ~/workspace/docs-platform-automation-reference-pipeline-config/foundations/sandbox/vars/pks.yml
   ```
   	> FYI... YAML is a superset of JSON. This means that any JSON is a valid YAML file!  The om tooling only parses files with var files with `.yml|.yaml` extensions so that's why we're using .yml extensions on the files we're writing JSON output to.


1. The terraform outputs contain secrets.
 
   **_REMEMBER_**: `docs-platform-automation-reference-pipeline-config` is a public repo.

   We will need to strip out any secrets before committing our updated vars files.
   
   Update the following values in [`export.yml`](https://github.com/pivotal/platform-automation-deployments/blob/main/concourse-credhub/export.yml) using values from the terraform outputs:

   * /concourse/main/reference-pipeline/service_account_key
   * /concourse/main/reference-pipeline/ops_manager_service_account_key
   * /concourse/main/reference-pipeline/ssl_certificate
   * /concourse/main/reference-pipeline/ssl_private_key
   * /concourse/main/reference-pipeline/ops_manager_ssh_private_key
   * /concourse/main/reference-pipeline/ops_manager_ssh_public_key
   * /concourse/main/vsphere_private_ssh_key (should be updated with the same value as `ops_manager_ssh_private_key`)
     
   Also update any other secrets from the terraform outputs in the `export.yml`

   Remove the above secrets from `vars/director.yml`, `vars/tas.yml`, `vars/pks.yml`

   We also needed to delete the `ops_manager_dns` secret from `foundations/sandbox/vars/director.yml` because we need the prepare-tasks-with-secrets task to pull it's value from Credhub.

	> Secrets in om's env.yml file are a special case and need to be stored in Credhub and passed as Environment Variables in the task.yml (ops_manager_dns should already be in export.yml and doesn't need to be updated)

1. To store/edit values in Credhub, export the vars from the `.envrc` in `platform-automation-deployments/concourse-credhub`.
   You can now access Credhub as normal. Run:
    ```bash
    credhub import -f export.yml
    ```

1. Commit all changes
1. Replace the [`state-sandbox.yml`](https://s3.console.aws.amazon.com/s3/buckets/ref-pipeline-state?region=us-west-2&tab=objects) stored in s3 with an empty file of the same name.
   ```
   touch state-sandbox.yml
   aws --profile=platform-automation s3 cp state-sandbox.yml s3://ref-pipeline-state/state-sandbox.yml
   ```
   
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
    uaac target https://api.pks.reference-gcp.gcp.platform-automation.cf-app.com:8443 --ca-cert /tmp/releng_ca_certificate
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

#### Create the Reference Pipeline SSL certificate
The [Paving](https://github.com/pivotal/paving) terraform recipes require a SSL certificate as input for the HTTPS load balancer that sits in front of the Foundation's router instances.

GCP Load Balancers [do not support](https://issuetracker.google.com/issues/35904953) (as of July, 2023) the 3072 bit private key length of Certificates generated by bosh, so we are using Credhub to generate our certificate.

1. Target the Platform Automation Concourse Credhub instance.
  * `cd ~/workspace/platform-automation-deployments/concourse-credhub`
1. Grab a copy of the [Releng CA Certificate](https://3.basecamp.com/4957863/buckets/20459415/documents/4860240754) and upload it to to Credhub so we can sign our new certificate with it.
  * `credhub set -t certificate -n '/concourse/main/reference-pipeline/ca_certificate' -c /tmp/releng.crt -p /tmp/releng.key`
1. Generate a 2048 bit key signed by our CA with the correct SANs for our reference foundation.

  ```
  credhub generate -t certificate --ca /concourse/main/reference-pipeline/ca_certificate -n /test/reference-certificate -d 720 \
  -k 2048 -o VMware -u PPE -i "San Francisco" -s California -y US \
  -c reference-gcp.gcp.platform-automation.cf-app.com \
  -a "*.sys.reference-gcp.gcp.platform-automation.cf-app.com" \
  -a "*.apps.reference-gcp.gcp.platform-automation.cf-app.com" \
  -a "*.pks.reference-gcp.gcp.platform-automation.cf-app.com" \
  -a "*.reference-gcp.gcp.platform-automation.cf-app.com"
  ```
1. Save the new certificate and private key.
  * `platform-automation-deployments/reference-gcp/terraform.tfvars`
  * `platform-automation-deployments/concourse-credhub/export.yml`
1. Update the Credhub instance with new values.
  * `credhub import -f export.yml`

#### Rotating the Reference Pipeline Environment's certificates

In our pipeline for the reference pipeline, there is a job called "[expiring-certificates](https://platform-automation.ci.cf-app.com/teams/main/pipelines/reference-pipeline/jobs/expiring-certificates/builds/latest)". This job will check the expiration dates for all of the certificates that the environment's ops manager knows about.

It does this by using `om --env env/foundations/config/env.yml expiring-certificates --expires-within 2m`.

If the job fails, then you'll need to read the error message which will have a description of the certificate that is expiring. It will also have a link to documentation on how to rotate the certificate. However, that link is out of date as of 2024-03-06. Here is an up to date version of the documentation: [Rotating CAs and leaf certificates using the Tanzu Operations Manager API](https://docs.vmware.com/en/VMware-Tanzu-Operations-Manager/3.0/vmware-tanzu-ops-manager/security-pcf-infrastructure-rotate-cas-and-leaf-certs.html).

## Docs Maintenance & Doc Updates
The general docs for this codebase are located in the [/docs](https://github.com/pivotal/docs-platform-automation/blob/develop/docs) directory of this repo.

Release notes and release-specific docs can be found in the release branches for their respective versions:
   * [`Platform Automation v5.2.x` branch](https://github.com/pivotal/docs-platform-automation/blob/v5.2/docs)
   * [`Platform Automation v5.1.x` branch](https://github.com/pivotal/docs-platform-automation/blob/migration-v5.1/docs)


The Docs team build the docs & release notes for Platform Automation using [DocWorks](docworks.vmware.com). Because they do this great service for us, if you need to make changes to the docs, please do so via a PR to the corresponding doc branch & tag [Anita Flegg](https://github.com/anita-flegg) for review. Anita will perform a build with your PR branch to verify the Docs compile properly before submitting.


## OM Releases

In the [OM CI Group](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci?group=om), the [`download-and-test-om`](https://platform-automation.ci.cf-app.com/teams/main/pipelines/ci/jobs/download-and-test-om/builds/latest) will run daily. This job downloads the latest code from the OM cli repo, and executes its bundled test suite. As long as it is green & passing, then you are safe to create a new release.

[Depending what kind of release you need to do](https://semver.org/), trigger a new build.
After the CI has completed go to [Github](https://github.com/pivotal-cf/om/releases) and update the release notes.

*Most* OM cli users will utilize the version that is bundled with their version of the Platform Automation toolkit. Each OM cli bump should be accompanied by a new Platform Automation release that contains the new OM cli version.

## Slack and Support

### Bugs in [Tracker](https://www.pivotaltracker.com/n/projects/2535033)
#### Github issues
When an issue is opened on the `om` or `docs-platform-automation`
a bug is auto-created in the Pivotal Tracker icebox.
Bugs generally have the format `git-org/project` with the name of the issue.

Ideally, issues should have a response from a dev 1+/wk
until an agreed-upon solution-proposal is found.
If there is no response from the issue opener,
give a reminder on the issue after 1 week.
After a second week, if there is still no response,
close the issue with a kind message and leave it up to the poster to reopen.
If the issue is reopened, a new bug will be generated in the Pivotal Tracker icebox.

#### CVEs
Ubuntu CVEs will also auto-populate in the Pivotal Tracker icebox.
These have the format:
```
**[Security Notice]** New USN
affecting Platform Automation Toolkit:
USN-####-#: pkg-name vulnerability
```
These should be handled using the steps detailed in the `CVEs and Patching Steps` section.

