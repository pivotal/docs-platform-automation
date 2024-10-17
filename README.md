# Introduction

This is the download source for
[Platform Automation Toolkit](https://support.broadcom.com/group/ecx/productdownloads?subfamily=Platform%20Automation%20Toolkit
),
available from the Broadcom Support portal.

The production docs are here:
https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/platform-automation-toolkit-for-tanzu/5-2/vmware-automation-toolkit/docs-index.html

There is a staging copy here:
https://author-techdocs2-prod.adobecqms.net/us/en/vmware-tanzu/platform/platform-automation-toolkit-for-tanzu/5-2/vmware-automation-toolkit/docs-index.html

# Usage

>**Important**: Mkdocs is no longer used. This doc set is now built in DocWorks.
>Contact your writer on the TAS IX team for help building the docs.
>See https://docworks.vmware.com/one/scene?permalink=uniqueId%3DMarkdown-Project-3084.


We use [`mkdocs`](https://www.mkdocs.org/) for our documentation engine.
To use it locally, it will require `python3` to be installed.

```
pip3 install -U -r requirements.txt
brew install ripgrep
git submodule update --init --recursive
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

# CI

Platform Automation
[ci](https://platform-automation.ci.cf-app.com/teams/main/pipelines/python-mitigation-support),
[support-pipeline](https://platform-automation.ci.cf-app.com/teams/main/pipelines/support-pipeline),
and
[python-mitigation-support](https://platform-automation.ci.cf-app.com/teams/main/pipelines/python-mitigation-support) pipelines are managed from this repo in the ci directory.

# Contributing

Please see the [contribution doc](CONTRIBUTING.md) for more information.

# Notes for Maintainers

There is a separate [Maintainers' Guide](MAINTAINERS_GUIDE.md)
intended for personnel allocated to maintenance
of the Platform Automation Toolkit.
