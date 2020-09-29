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
   This should be updated in `docs-platform-automation/ci/cve-patch-notes/cve-patch-notes.md`
   The bug fixes for the last release should be already populated.
   Replace the existing release notes with the release notes for the newest patch.
1. Commit the changes
1. Trigger the `build-all-versions-image` job in the [`bump`](https://platform-automation.ci.cf-app.com/teams/main/pipelines/bump) pipeline

   This will trigger the CVE process.
   To validate the appropriate CVEs were updated in supported versions,
   wait until the `update-vX.X` job has completed,
   then download the `image-receipt-x.x.x` from AWS S3
   (this link is also be available in the release notes for each version).

Note: if,for some reason, any `update-vX.X` job fails,
the job can be re-run and will not re-generate release notes.
However, the release date of the job
will be whatever the date of the first run for the patch was.
The task that generates the release notes for each minor/major version
is called `create-release-notes-for-patch`.
This task exists in all `update-vX.X` jobs.


### Updating the Release Notes Manually
There is an easy (manual) way to undo the docs created for CVE patching.
This could be due to:
- failure to update the `cve-patch-notes.md` before creating the patch
- some other reason

The following steps are a manual process to "revert"
the generated release notes and re-create them manually.
Note: if due to a failed build, you _must_ stop before the last step.
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

1. with an updated `docs-platform-automation/ci/cve-patch-notes/cve-patch-notes.md`
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
