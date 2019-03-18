View the most recent release of the [docs](https://docs.pivotal.io/platform-automation/)

For internal Pivotal, you can see up-in-coming release changes in our [staging-docs](http://docs-pcf-staging.cfapps.io/platform-automation/develop/)

to download dependencies:
pip3 install -r requirements.txt
brew install ripgrep 

to build the mkdocs "final_app" (`site` in the mkdocs repo), run `mkdocs build` in the new docs directory

to update the mkdocs dependencies, run `pip3 -r requirements.txt -U`

to run the app, run `mkdocs serve` from the same directory

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

* to find broken anchors in the app, run the `./bin/find_broken_anchors.rb` script from github.com/jtarchie/docs-converter repo
* requires ruby version 2.5.1
* after being converted, docs can be edited as markdown in html in the `docs` directory
