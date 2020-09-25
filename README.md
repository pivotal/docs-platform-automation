# Introduction

This is the docs source for
[Platform Automation Toolkit](https://network.pivotal.io/products/platform-automation),
available from VMware Tanzu Network.

The production docs are here:
https://docs.pivotal.io/platform-automation/

There is a public staging copy here:
https://docs-pcf-staging.cfapps.io/platform-automation/

# Usage

We use [`mkdocs`](https://www.mkdocs.org/) for our documentation engine.
To use it locally, it will require `python3` to be installed.

```
pip3 install -U -r requirements.txt
brew install ripgrep
mkdocs serve
``` 

**Notes**
* `serve`ing the app will check for broken external links.
  An error in a link might show like so:

```
○ → mkdocs serve
INFO    -  Building documentation...
INFO    -  Cleaning site directory
INFO    -  The following pages exist in the docs directory, but are not included in the "nav" configuration:
WARNING -  Documentation file 'task-reference.md' contains a link to 'asdfasdf.html' which is not found in the documentation files.

Exited with 1 warnings in strict mode.
```

# Contributing

Please see the [contribution doc](CONTRIBUTING.md) for more information.

# Maintainer's Guide Notes

## CVEs and Patching
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

### What if I Forgot to Update the CVE Patch File?
There is an easy (manual) way to undo the docs created for CVE patching
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
Dont. Revert any such changes to those patch versions.

Platform Automation is strictly [semvered](https://semver.org/)
with an API defined in our [docs](https://docs-pcf-staging.cfapps.io/platform-automation/develop/compatibility-and-versioning.html#semantic-versioning).

Patching of this product should _never_ include features or breaking changes.
