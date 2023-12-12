# Why use Git and GitHub?

GitHub is a system that provides Git remotes,
essentially, an internet accessible backup to the git repositories on your computer.
Using a remote will enable a pipeline
to access and update the state and configuration files.

Git is a commonly used version control tool.
It can be used to track code changes made to files within a repository (or "repo").
Changes can then be "pushed" to or "pulled" from remote copies of that repository.

<p class="note">
<span class="note__title">Note</span>
There are many alternatives to GitHub including
Gitlabs, Google Cloud Source Repositories, etc.
Any remote Git client will work with Platform Automation Toolkit and Concourse.
See the <a fref="https://github.com/concourse/git-resource">Concourse Git resource</a>
documentation for details.</p>

To learn more about Git and GitHub,
you can [read this short git handbook](https://docs.github.com/en/get-started/using-git/about-git).

## Creating a Git Repository

To create a new, local Git repo:

```bash
# start a new repository
git init my-platform-automation

# navigate to the new directory it creates
cd my-platform-automation

# create a new directory for your config
mkdir config

# create remaining directories
mkdir env state vars

# create config files for director and opsman
touch config/director.yml
touch config/opsman.yml

# create env file
touch env/env.yml

# create state file
touch state/state.yml

# Optional:
# create vars files for parameters corresponding to configs
touch vars/director-vars.yml
touch vars/opsman-vars.yml

# commit the file to the repository
git commit -m "add initial files"
```

## Creating a GitHub Repository

Next, navigate to GitHub and create a new remote repository.

1. Under your profile, select "Repositories"
1. Select "New"
1. Name your new repository and follow the prompts
1. Do not select to add any default files when prompted
1. Copy the URL of your new GitHub repository

Now, we can set the local Git repo's
remote to the new GitHub repo:

```bash
# enter the path for the new GitHub repo
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git

# push your changes to the default branch
git push --set-upstream origin main
```

You should now see your GitHub repo populated
with the directories and empty files.

<p class="note important">
<span class="note__title">Important</span>
A GitHub repository may be referenced
as a remote repo by HTTPS or by SSH.
In general, SSH keys are more secure.
The <a href="https://docs.github.com/en/get-started/using-git/about-git">Concourse Git resource</a>
supports using SSH keys to pull from a repository.
For more information on using SSH keys with GitHub,
see this 
[SSH documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/about-ssh)</p>

## Recommended file structure

You now have both a local Git repo and a remote on GitHub.
The above commands give you the recommended structure
for a Platform Automation Toolkit configuration repo:

```tree
├── my-platform-automation
│   ├── config
│   ├── env
│   ├── state
│   └── vars
```      

<table>
    <tr>
        <td>config</td>
        <td>
            Holds config files for the products installed on your foundation.
            If using CredHub and/or vars files,
            these config files should have your <code>((parametrized))</code> values present in them
        </td>
    </tr>
    <tr>
        <td>env</td>
        <td>
            Holds <code>env.yml</code>,
            the environment file used by tasks that interact with Tanzu Operations Manager.
        </td>
    </tr>
    <tr>
        <td>vars</td>
        <td>
          Holds product-specific vars files.
          The fields in these files get used to fill in
          <code>((parameters))</code> during interpolation steps.
        </td>
    </tr>
    <tr>
        <td>state</td>
        <td>
            Holds <code>state.yml</code>,
            which contains the VM ID for the Tanzu Operations Manager VM.
        </td>
    </tr>
</table>

For further details regarding the contents of these files,
see [Inputs and outputs](../inputs-outputs.md).


<p class="note caution">
<span class="note__title">Caution</span>
Never commit secrets to Git.
It is a best practice **_not_** to commit secrets,
including passwords, keys, and sensitive information,
to Git or GitHub. Instead, use <code>((parameters))</code>.
For more information about a recommended way to do this
using CredHub or vars files
see <a href="../concepts/secrets-handling.md">Using a secrets store to store credentials.</a></p>

## Multi-foundation

The above is just one example of how to structure your configuration repository.
You may instead decide to have a repo for just config files and separate repos
just for vars files. This decouples the config parameter names from their values
for multi-foundation templating.

There are many possibilities for structuring Git repos in these complex situations.
For guidance on how to best set up your git's file structure,
refer to the [Inputs and outputs](../inputs-outputs.md) documentation
and take note of the `inputs` and `outputs` of the
various [Platform Automation Toolkit tasks](../tasks.md).
As long as the various input / output mappings correctly correlate
to the expected ins and outs of the Platform Automation Toolkit tasks,
any file structure could theoretically work.

[//]: # ({% with path="../" %})
[//]: # (    {% include ".internal_link_url.md" %})
[//]: # ({% endwith %})
[//]: # ({% include ".external_link_url.md" %})
