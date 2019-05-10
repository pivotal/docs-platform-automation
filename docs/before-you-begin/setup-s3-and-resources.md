# Set Up S3 for File Storage

Platform Automation uses and produces
file artifacts that are too large to store in git.
For example, many `.pivotal` product files are several gigabytes in size.
Exported installation files may also be quite large.
The recommended way to store these files
is in a Amazon S3 compatible object store,
commonly referred to simply as _"S3"_ or _"blobstore"_.

## The S3 Value

Suppose that you have a Concourse or OpsMan environment
that can't access the greater internet,
including PivNet.
This is a common security practice
but it creates a problem around upgrading.
If products cannot be downloaded from PivNet directly,
how can we get the latest version of something
and send it through an upgrade pipeline?

Enter S3 and Concourse's native S3 integration!
We can place product files
and new versions of OpsMan
into a network whitelisted S3 bucket
to be used by Platform Automation tasks.
We can even create a [Resources Pipeline][reference-resources]
that gets the latest version of products
from PivNet and places them into our S3 bucket automatically.

Alternatively, because a foundation's backup
may be quite large,
it is advantageous to persist it in a blobstore
automatically through Concourse.
Exported installations can then latter be accessed
through the blobstore.
Because most object stores
implement secure, durable solutions,
exported installations in buckets 
are easily restorable
and persistent. 

In this guide,
you will learn 
how to set up an Amazon S3 bucket,
how bucket permissions work,
what we can store in a bucket,
and how a pipeline may be set up
to retrieve and store objects.

## Pre-requisites

1. An [Amazon Web Services account][amazon-s3] (commonly referred to as AWS) with access to S3

!!! note "S3 blobstore compatibility"
    Many cloud storage options exist
    including [Amazon S3][amazon-s3],
    [Google Storage][gcp-storage],
    [Minio][minio],
    and [Azure Blob Storage][azure-blob-storage].
    However, not all object stores
    are "S3 compatible".
    Because Amazon defines the 
    S3 API for accessing blobstores,
    and because the Amazon S3 product has emerged as the dominant blob storage solution,
    not all "S3 compatible" object stores act exactly the same.
    In general, if a storage solution claims to be "S3 compatible",
    it should work with the [Concourse's S3 resource integration][concourse-s3-resource].
    But note that it may behave differently if interacting directly with the S3 API.
    Defer to the documentation of your preferred blobstore solution 
    when setting up storage.
 
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
Now you are ready for buckets!

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
    
    For simplicity, in the rest of this guide,
    we will use the AWS root user
    to show how a bucket may be set up and used with Platform Automation.

 
## Your first Bucket

1. Navigate to [the S3 console][amazon-s3-console].
1. Click the "Create bucket" button.
1. Enter a DNS-compliant name for your new bucket
    - This name must be unique across all of AWS S3 buckets
    and adhere to general URL guidelines. 
    Make it something meaningful and memorable!
1. Enter the "Region" you want the bucket to reside in.
1. Choose "Create".

This creates a bucket with the default S3 settings.
Bucket permissions and settings
can be set during bucket creation or changed afterwards.
Bucket settings can even be copied from other buckets you have.
For a detailed look at creating buckets
and managing initial settings,
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

Amazon S3 has the following Access permissions:

- *Public* - Everyone has access to one or more of the following: 
List objects, Write objects, Read and write permissions
- *Objects can be public* - The bucket is not public.
But anyone with appropriate permissions can grant public access to objects. 
- *Buckets and objects not public* - The bucket and objects do not have any public access.
- *Only authorized users of this account* - Access is isolated to IAM users and roles.

In order to change who can access buckets or objects in buckets:

1. Navigate to [the S3 console][amazon-s3-console].
1. Choose the name of the bucket you created in the previous step
1. In the top row, choose "Permissions"

In this tab,
you can set the various permissions
for an individual bucket. 
For simplicity, in this guide, we will use public permissions
for Concourse to access the files.

1. Under the permissions tab for a bucket, choose "Public access settings"
1. Choose "Edit" to change the public access settings
1. Uncheck all boxes to allow public access. 

In general, the credentials being used 
to access an S3 compatible blobstore through Concourse
must have `Read` and `Write` permissions.
It is possible to use different user roles
with different credentials
to seperate which user can `Read`
objects from the bucket
and which user can `Write` objects to the bucket.

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
we will want to enable versioning. Enabling versioning is not required,
but versioning does make the process easier, 
and will require less potential manual steps around naming updates to the new file 
whenever they are changed. 

1. Navigate to [the S3 console][amazon-s3-console].
1. Choose the name of the bucket you created in the previous step
1. Select the "Properties" tab
1. Click the "Versioning" tile
1. Check the "Enable Versioning" 

Now that versioning is enabled, 
we can store multiple versions of a file.
For example, given the following object:
``` 
my-exported-installation.zip
```
We can now have multiple versions of this object stored in our S3 bucket:
```
my-exported-installation.zip (version 111111)
my-exported-installation.zip (version 121212)
``` 

## What to store in S3

Any file that can be stored on a computer 
can be stored on S3.
> " ... store and retrieve any amount of data, at any time, from anywhere on the web."
> - [Amazon S3][amazon-s3]

S3 is especially good at storing large files
as it is designed to scale with large amounts of data
while still being durable and fast.

Platform Automation users may want to store the following files in S3:

- `.pivotal` product files
- `.tgz` stemcell files
- `.ova` OpsManager files
- `.zip` foundation exports

Platform Automation users will likely **_NOT_** want to store the following in S3:

- `.yaml` configuration files - Better suited for [git][git]
- `secrets.yaml` environment and secret files - There are a number of ways
to handle these types of files, 
but they should not be stored in S3.
Check out the [Secrets Handling page][secrets-handling]
for how to work with these types of files.  

## How to structure your bucket

Like any computer, buckets can have folders 
and any number of sub-folders.
The following is one way to set up your bucket's file structure: 

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
simple select "Create Folder".
To create a sub-folder,
when viewing a specific folder,
select "Create Folder" again.  

When attempting to access a specific object in a folder,
simply include the folder structure before the object name:

```
foundation1/products/healthwatch/my-healthwatch-product.pivotal
```

## Using a Bucket

When using the [Concourse S3 Resource][concourse-s3-resource],
several configuration properties are available
for retreiving objects
The bucket name is required.

!!! Note "On networking and accessing a bucket"
    In order for your Concourse 
    to have access to your Amazon S3 bucket,
    ensure that you have the appropriate firewall and networking settings
    for your Concourse instance to
    make requests to your bucket. 
    Concourse uses various "outside" resources
    to perform certain jobs.
    Ensure that Concourse can "talk" to your Amazon S3 bucket.


## Reference Resources Pipeline

#### Usefulness

The [resources pipeline][reference-resources]
may be used to download dependencies from Pivnet
and place them into a trusted S3 bucket.
The various `resources_types` use the [Concourse S3 Resource type][concourse-s3-resource]
and several Platform Automation tasks to accomplish this.
The following is a S3-specific breakdown of these components
and where to find more information.

#### The download-product Task

The [`download-product`][download-product] task lets you download products from PivNet.
If S3 properties are set in the [download config][download-product-config],
these files can be placed into an S3 bucket. 

If S3 configurations are set,
this task will perform a specific filename operation
that will prepend meta data to the filename.
If downloading the product `Example Product version 2.2.1` from PivNet
where the product slug is `example-product` and the version is `2.2.1`,
when directly downloaded from PivNet, the file may appear as:

```
product-2.2-build99.pivotal
```

Because PivNet file names
do not always have the necessary metadata required by Platform Automation,
the download product task will prepend the necessary information
to the filename before it is placed into the S3 bucket:

```
[example-product,2.2.1-build99]product-2.2-build99.pivotal
```

For complete information on this task
and how it works, refer to the [download-product task reference.][download-product]

!!! warning "Changing S3 file names"
    Do not change the meta information 
    prepended by `download-product`.
    This information is required by the
    `download-product-s3` task to properly parse product versions.
    
    If placing a product file into an S3 bucket manually,
    ensure that it has the proper file name format;
    opening bracket, the product slug, a single comma, the product's version, and finally, closing bracket.
    There should be no spaces between the two brackets.
    For example, for a product with slug of `product-slug` and version of `1.1.1`:
    ```
    [product-slug,1.1.1]original-filename.pivotal
    ```

#### The download-product-s3 Task

The [`download-product-s3`][download-product-s3] 
task lets you download products from an S3 bucket.
The prefixed metadata added by `download-product` is used to find the appropriate file.
This task uses the same [download-product config file][download-product-config]
as `download-product` to ensure consistency 
across what is `put` in S3
and what is being accessed latter by `download-product-s3`.
`download-product` and `download-product-s3` are designed
to be used together. 
The download product config should be different between the two tasks.

For complete information on this task
and how it works, refer to the [download-product-s3 task reference.][download-product-s3]

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
