# Pivotal Cloud Foundry Partners Template

This template helps partners prepare documentation for Pivotal Cloud Foundry (PCF) partner services that appear on [Pivotal Network](https://network.pivotal.io/). 

## <a id='overview'></a>Overview

Every partner service in PCF is documented on our PCF documentation site. The links to these partner service docs appear on the [front page](http://docs.pivotal.io) under **Partner Services for Pivotal Cloud Foundry**.

For a good example of a partner service doc, see [MongoDB Enterprise Service for PCF](https://docs.pivotal.io/partners/mongodb/index.html).

## <a id='template'></a>How To Use This Template

Partners use this template to develop the documentation for their PCF service. This repo currently includes templates for the following topics:

* [index.html.md.erb](./docs-content/index.html.md.erb): The index of your docs.
* [installing.html.md.erb](./docs-content/installing.html.md.erb): How to install and configure your product tile.
* [using.html.md.erb](./docs-content/using.html.md.erb): How to use your product.
* [release-notes.html.md.erb](./docs-content/release-notes.html.md.erb): Release notes for your product.

To begin using this repo to develop your documentation, perform the following steps:

1. Make a fork of this repo.
1. Clone your fork onto your local machine.
1. Work your way through each topic, replacing the placeholders in ALL-CAPS and following the instructions in **bold**. 
    * When writing your documentation, follow the guidelines in [Style Notes for Tile Authors](style-guide.md).
1. Complete the subnav by replacing the placeholders in ALL-CAPS in the subnav file at `docs-book/master_middleman/source/subnavs/myservice_subnav.erb` in this repo.
1. View your documentation as a live local site in a browser, by following the steps below in the [How To Use Bookbinder To View Your Docs](#bookbinder) section.
1. When you've finished your documentation, make a pull request to merge your fork into this repo and email the PCF Docs Team at cf-docs@pivotal.io.

## <a id='bookbinder'></a>How To Use Bookbinder To View Your Docs

[Bookbinder](https://github.com/pivotal-cf/bookbinder/blob/master/README.md) is a command-line utility for stitching Markdown docs into a hostable web app. The PCF Docs Team uses Bookbinder to publish our docs site, but you can also use Bookbinder to view a live version of your documentation on your local machine.

Bookbinder draws the content for the site from `docs-content`, the subnav from `docs-book`, and various layout configuration and assets from `docs-layout`.

To use Bookbinder to view your documentation, perform the following steps:

1. Install Bookbinder by running `gem install bookbindery`. If you have trouble, consult the [Zero to Bookbinder](#zero-to-bookbinder) section to make sure you have the correct dependencies installed.
1. On your local machine, `cd` into `docs-book` in the cloned repo.
1. Run `bundle install` to make sure you have all the necessary gems installed.
1. Build your documentation site with `bookbinder` in one of the two following ways:
	* Run `bundle exec bookbinder watch` to build an interactive version of the docs and navigate to `localhost:4567/myservice/` in a browser. (It may take a moment for the site to load at first.) This builds a site from your content repo at `docs-content`, and then watches that repo to update the site if you make any changes to the repo.
	* Run `bundle exec bookbinder bind local` to build a Rack web-app of the book. After the bind has completed, `cd` into the `final_app` directory and run `rackup`. Then navigate to `localhost:9292/myservice/` in a browser.

## <a id='zero-to-bookbinder'></a>Zero to Bookbinder: How to Install Bookbinder and Build, View, and Edit Your Docs from Nothing

If you are reading this, Pivotal has invited you to a git repo where you can build and edit documentation in the Ruby / Markdown / HTML format that the online publishing tool [Bookbinder](https://github.com/pivotal-cf/bookbinder/blob/master/README.md) uses to build Pivotal's documentation.

Here's how to install Bookbinder and build your docs from the repo, starting from scratch, on a Mac OS X machine.

<p class="note"><strong>Note</strong>: All steps below are implicitly preceded with, "If you haven't already..." You should skip any installation steps that have already contributed to your environment.</p>

## Install Ruby

In Terminal window:

1. Make and `cd` into a workspace directory.

    `$ mkdir workspace`

     `$ cd workspace`

1. Follow the instructions at `http://brew.sh` to install brew / homebrew

    `$ /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`

1. Install your own (non-system) ruby.

    `$ brew install ruby`

## Set up Git

1. Download and Install git by following the instructions at [git-scm.com](https://git-scm.com/download/).

1. Install your own (non-system) bash-completion (optional).

    `$ brew install git bash-completion`

1. If you don't already have one, generate a public/private RSA key pair, and save the key to your `~/.ssh` directory.
    ```
    $ ssh-keygen
    Generating public/private rsa key pair.
    Enter file in which to save the key (/Users/pspinrad/.ssh/id_rsa): 
    ```

1. Get a [Github](http://github.com) account.

1. Add your RSA public key to your Github account / profile page.

    `$ cat ~/.ssh/id_rsa.pub # copy and paste this into Github profile page as new key`

## Get the Correct Ruby Version for Bookbinder: Ruby 2.3.0

1. Install a Ruby manager such as chruby.

    `$ brew install chruby`

1. Add your Ruby manager to your `~/.bashrc` by appending the following line:

    `source /usr/local/opt/chruby/share/chruby/chruby.sh`

1. Install the `ruby-install` installer.

    `$ brew install ruby-install`

1. Run `ruby-install` to install Ruby 2.3.0.

    `$ ruby-install ruby 2.3.0`

1. Select the following Ruby version.

    `chruby ruby-2.3.0`

## Install Bookbinder

1. Install `bundler`.

    `$ gem install bundler`

1. Install bookbinder (the `bookbindery` gem).

    `$ gem install bookbindery`

## Build the Docs Locally

1. Clone the docs template repo you will be building from.

    `$ git clone git@github.com:pivotal-cf/docs-partners-template`

1. `cd` into the `book` subdirectory of the repo.

   `$ cd docs-partners-template/docs-book`

1. Run `bundle install` to install all book dependencies.

    `$ bundle install`

1. Run `bundle exec bookbinder watch` to build the book on your machine.

   `$ bundle exec bookbinder watch`
   
1. Browse to `localhost:4567` to view the book locally and "watch" any changes that you make to source `html.md.erb` files. As you make and save changes to the local source files for your site, you will see them in your browser after a slight delay.

1. After each session of writing or revising your docs source files, commit and push them to your github repo.

## About Subnavs of Published Tile Documentation

After your tile documentation has been published, the subnav used for the live documentation is contained in this directory: https://github.com/pivotal-cf/docs-book-partners/tree/master/master_middleman/source/subnavs

However, you should also continue to maintain the local subnav file so that the subnav looks correct when you or a Pivotal writer builds your documentation locally with bookbinder for review or editing.

To edit a subnav for your tile documentation, follow these steps:

1. Make a pull request against the subnav file in https://github.com/pivotal-cf/docs-book-partners/tree/master/master_middleman/source/subnavs

2. Make the same changes in the subnav file (in /docs-book/master_middleman/source/subnavs/ of your tile repo) and make a pull request for that change too.

Happy documenting!

![Partner Template landing page](./docs-book/master_middleman/source/images/partner-template-landing.png)

![Partner Template service index page](./docs-book/master_middleman/source/images/partner-template-service-index.png)

