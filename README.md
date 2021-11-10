# Introduction

This is the docs source for
[Platform Automation Toolkit](https://network.pivotal.io/products/platform-automation),
available from VMware Tanzu Network.

The production docs are here:
https://docs.pivotal.io/platform-automation/

There is a public staging copy here:
https://docs-pcf-staging.tas.vmware.com/platform-automation/

# Usage

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

# Contributing

Please see the [contribution doc](CONTRIBUTING.md) for more information.

# Notes for Maintainers

There is a separate [Maintainers' Guide](MAINTAINERS_GUIDE.md)
intended for personnel allocated to maintenance
of the Platform Automation Toolkit.
