# Introduction

This is the source of the docs for the [Platform Automation](https://network.pivotal.io/products/platform-automation) package downloaded from Pivotal Network.

The docs can be viewed at: https://docs.pivotal.io/platform-automation/ 

# Usage

We use [`mkdocs`](https://www.mkdocs.org/) for our documentation engine.
To use it locally, it will require `python3` to be installed.

```
pip3 install -U -r requirements.txt
brew install ripgrep
mkdocs serve
``` 

**Notes**
* `serve`ing the app will check for broken external links. An error in a link might show like so:

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