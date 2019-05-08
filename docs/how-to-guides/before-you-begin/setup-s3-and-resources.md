# Setup S3 for File Storage

Platform Automation uses 
file artifacts that are too large to store in git.
For example, many `.pivotal` product files are several gigabytes in size.
The recommended way to store these files
is in a Amazon S3 compatible object store,
commonly referred to simply as "S3" or "blobstore".

## The S3 Value

Suppose that you have a Concourse or OpsMan environment
that can't access the greater internet,
including PivNet itself.
This is a common security practice
but it creates a problem around upgrading.
If products cannot be downloaded from PivNet directly,
how can we get the latest version of something
and send it through our upgrade pipeline?

Enter S3 and Concourse's native S3 integration!
We can place product files
and new versions of OpsMan
into a network whitelisted S3 bucket
to be used by Platform Automation tasks.
We can even create a "Resources Pipeline"
that gets the latest version of products
from PivNet and places them into our S3 bucket automatically.

Additionally, because a foundation's backup
may be quite large,
it is advantageous to persist it in a blobstore.
Exported installations can then latter be acessed
through the blobstore.

In this guide,
you will learn 
how to set up an Amazon S3 bucket,
how bucket permissions work,
what we can store in a bucket,
and how a pipeline may be set up
to retrieve and store objects.

## Pre-requisites

TODO: Need all these things? 
1. A unix-like workstation
    - with a text editor you like
    - a terminal emulator
    - a browser that works with Concourse, like Firefox or Chrome
1. A Concourse instance with access to the internet
1. The `fly` command line tool
1. An account on [PivNet][pivnet]
1. An [Amazon Web Service account][amazon-s3] (commonly referred to as AWS) with access to S3
 
## Set up S3

S3 stores data as objects within buckets.
An object is any file that can be stored on a file system.
Buckets are the containers for objects.
Buckets can have permissions for who can
create, write, delete, and see objects within that bucket.

With your AWS account,
navigate to [the S3 console][amazon-s3-console]
and sign up for S3. 
Follow the on screen prompts.
Now we are ready for buckets!

!!! tip "AWS Root User"
    When you sign up for the S3 service on Amazon,
    the account with the email and password you use
    is the AWS account root user.
    As a best practice,
    you should not use the root user
    to access and manipulate services. 
    Instead, use [AWS Identity and Access Management][amazon-iam]
    (commonly refered to as IAM)
    to create and manage users.
    For more info on how this works,
    check out this [guide from Amazon][amazon-iam-guide].
    
    In the rest of this guide,
    we will use the AWS root user
    to show how a bucket may be set up and used with Platform Automation.

 
## Your first Bucket

1. Navigate to [the S3 console][amazon-s3-console].
1. Click the "Create bucket" button.
1. Enter a DNS-compliant name for your new bucket
    - This name must be unique across all of AWS S3 buckets
    and adhere to general URL guidelines. 
    Make it something meaningful and rememberable!
1. Enter the "Region" you want the bucket to reside in.
1. Choose "Create".

This creates a bucket with the default S3 settings.
Bucket permissions and settings
can be set during bucket creation or changed afterwards.
Bucket settings can even be copied from other buckets you have.
For a detailed look at creating buckets on Amazon S3,
check out [this documentation on creating buckets.][amazon-s3-create-bucket]

## Bucket Permissions

By default, only the AWS account owner 
can access S3 resources, including buckets and objects.
The resource owner may allow public access,
allow specific IAM users permissions,
or create a custom access policy.

To view bucket permissions,
from the S3 console,
look at the "Access" column.

For Amazon S3,
these are the Access permissions:

- *Public* - Everyone has access to one or more of the following: 
List objects, Write objects, Read and write permissions
- *Objects can be public* - The bucket is not public.
But anyone with apprpriate permissions can grant public acccess to objects. 
- *Buckets and objects not public* - The bucket and objects do not have any public access.
- *Only authorized users of this account* - Access is isolated to IAM users and roles.

In order to change who can access buckets or objects in buckets:

1. Navigate to [the S3 console][amazon-s3-console].
1. Choose the name of the bucket you created in the previous step
1. In the top row, choose "Permissions"

In this tab,
you can set the various permissions
for an individual bucket. 
In this guide, we will use public permissions
so that Concourse can access the files.

1. Under the permissions tab for a bucket, choose "Public access settings"
1. Choose "Edit" to change the public access settings
1. Uncheck all boxes to allow public access. 

!!! Note "Permissions"
    Amazon S3 provides many [permission settings for buckets][amazon-s3-permissions].
    Specific [IAM users can have access][amazon-s3-permissions-iam].
    Objects can have [their own permissions][amazon-s3-permissions-objects].
    And buckets can even have their own [custom Bucket Policies][amazon-s3-permissions-policies].
    Refer to your organization's security policy
    to best set up your S3 bucket.

## Object Versions

By default,
an S3 bucket will be _unversioned_.
An unversioned bucket will not allow different versions of the same object.
In order to take advantage of using an S3 bucket with Platform Automation,
we will need to enable versioning. 

1. Navigate to [the S3 console][amazon-s3-console].
1. Choose the name of the bucket you created in the previous step
1. Select the "Properpties" tab
1. Click the "Versioning" tile
1. Check the "Enable versioning" 

Now that versioning is enabled, 
we can store multiple versions of a file.
For example, given the following object:
``` 
my-exported-installation.zip
```
We can now have have multiple versions of this object stored in our S3 bucket:
```
my-exported-installation.zip (version 111111)
my-exported-installation.zip (version 121212)
``` 

## What to store in S3

Any file that can be stored on a computer 
can be stored on S3.
> "... store and retrieve any amount of data, at any time, from anywhere on the web."
> - [Amazon S3 Docs][amazon-s3]

S3 is especially good at storing large files
as it is designed to scale with large amounts of data.

Platform Automation users may want to store the following files in S3:

- `.pivotal` product files
- `.ova` OpsManager files
- `.zip` foundation exports

## How to structure your bucket

Buckets can have folders and any number of sub-folders.
The following is one way to set up your bucket's folders: 

```
├── foundation-1
│   ├── products
│   │   ├── healthwatch
│   │   │     healthwatch.pivotal
│   │   ├── pas
│   │   │     pas.pivotal
│   │   └── ...
│   │
│   ├── stemcells
│   │   ├── healthwatch-stemcell
│   │   │     ubuntu-trusty.tgz
│   │   ├── pas-stemcell
│   │   │     ubuntu-xenial.tgz
│   │   └── ...
│   │
│   ├── foundation1-exports
│           foundation1-installation.zip

``` 

When viewing a bucket in the AWS S3 console,
simple select "Create folder".
To create a sub-folder,
when viewing a specific folder,
select "Create folder" again.  




## Using a Bucket with Concourse

!!! Note "A note on networking"
    In order for your Concourse 
    to have access to your Amazon S3 bucket,
    ensure that you have the appropriate firewall and networking settings
    for your concourse instance to
    make requests to your bucket. 
    Concourse uses various "outside" resources
    to perform certain jobs.
    Ensure that Concourse can "talk" to your Amazon S3 bucket. 


## Reference Resources

#### Usefulness

-- TODO --
The reference resources pipeline is great 

#### The Download Product Task

The `download-product` task lets you get products from PivNet.
These can be placed in a S3 bucket. 
Mention the file prefixing!

#### The Download Product S3 Task

The `download-product-s3` task lets you download products from an S3 bucket.
The prefix is used to find the files metadata.

To fetch a product from Pivnet, concourse needs to know:
 
* what image it will run the task on (`platform-automation-image`)
* where the task file will come from (`platform-automation-tasks`) 
* what config file it will read from to get data about pivnet and the tile (this is 
  the `download-product-config` created above)
* how to map the output from the task to something you will use later
* where to put the output resources created in the task

{% with path="../../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
