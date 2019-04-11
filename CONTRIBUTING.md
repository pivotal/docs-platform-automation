# Sign the CLA

If you have not previously done so, please fill out and
submit the [Contributor License Agreement](https://cla.pivotal.io).

# Contributing to the docs

All kinds of contributions to docs are welcome.

## Start with a github issue

In all cases, following this workflow will help all contributors to docs to
participate more equitably:

1. Search existing github issues that may already describe the idea you have.
   If you find one, consider adding a comment that adds additional context about
   your use case, the exact problem you need solved and why, and/or your interest 
   in helping to contribute to that effort.
2. If there is no existing issue that covers your idea, open a new issue to
   describe the change you would like to see in docs. Please provide as much
   context as you can about your use case, the exact problem you need solved and why,
   and the reason why you would like to see this change. If you are reporting a bug, 
   please include steps to reproduce the issue if possible.
3. Any number of folks from the community may comment on your issue and ask
   additional questions. A maintainer will add the `pr welcome` label to the
   issue when it has been determined that the change will be welcome. Anyone
   from the community may step in to make that change.
4. If you intend to make the changes, comment on the issue to indicate your
   interest in working on it to reduce the likelihood that more than one person
   starts to work on it independently.

# Running the docs

## Getting Started

Just clone the repo and start mkdocs.

### Clone the repo

```bash
git clone https://github.com/pivotal/docs-platform-automation
```

### View them from `mkdocs`

```bash
mkdocs serve
```

Then view them in your web browser by visiting the URL the previous command displayed.
Usually this is http://127.0.0.1:8000.
Changes you make will be updated locally in your web browser.

## Contributing your changes

1. When you have a set of changes to contribute back to docs, create a pull
   request (PR) and reference the issue that the changes in the PR are
   addressing. Ensure the PR is made against the correct version of the docs,
   which are branched by the release version on Pivnet, or contribute new docs
   directly to `develop`.
1. Your pull request will be reviewed by one or more maintainers. You may also
   receive feedback from others in the community. The feedback may come in the
   form of requests for additional changes to meet expectations for code
   quality or consistency. Or it could be clarifying questions to
   better understand the decisions you made in your implementation.
1. When a maintainer accepts your changes, they will merge your pull request.
   If there are outstanding requests for changes or other small changes they
   feel can be made to improve the changed code, they may make additional
   changes or merge the changes manually. It's always nice to have changes come
   in just as the team would like to see them, but we'll try not to hold up a pull
   request for a long period of time due to minor changes.