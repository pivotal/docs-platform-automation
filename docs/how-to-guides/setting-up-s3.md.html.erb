# Setting up S3 for file Storage

In this guide, you will learn
how to set up an S3 bucket,
how bucket permissions work,
what we can store in a bucket,
and how a pipeline may be set up
to retrieve and store objects.

## Why use S3?

* Platform Automation Toolkit uses and produces
file artifacts that are too large to store in git.
For example, many `.pivotal` product files are several gigabytes in size.
Exported installation files may also be quite large.

* For environments that can't access the greater internet.
  This is a common security practice,
  but it also means that it's not possible
  to connect directly to Tanzu Network
  to access the latest product versions for your upgrades.

S3 and Concourse's native S3 integration
makes it possible to store large file artifacts
and retrieve the latest product versions in offline environments.

With S3, we can place product files and new versions of OpsMan
into a network allow-listed S3 bucket
to be used by Platform Automation Toolkit tasks.
We can even create a [Resources pipeline](../pipelines/resources.md)
that gets the latest version of products
from Tanzu Network and places them into our S3 bucket automatically.

Alternatively, because a foundation's backup may be quite large,
it is advantageous to persist it in a blobstore
automatically through Concourse.
Exported installations can then later be accessed
through the blobstore.
Because most object stores implement secure, durable solutions,
exported installations in buckets
are easily restorable and persistent.

## Prerequisites

1. An [Amazon Web Services account(AWS)](https://aws.amazon.com/s3/) with access to S3

<p class="note">
<span class="note__title">Note</span>
S3 blobstore compatibility: Many cloud storage options exist
including <a href="https://aws.amazon.com/s3/">Amazon S3</a>,
<a href="https://cloud.google.com/storage/">Google Storage</a>,
<a href="https://min.io/">Minio</a>,
and <a href="https://azure.microsoft.com/en-us/products/storage/blobs/">Azure Blob Storage</a>.
However, not all object stores are "S3 compatible".
Because Amazon defines the S3 API for accessing blobstores,
and because the Amazon S3 product has emerged as the dominant blob storage solution,
not all "S3 compatible" object stores act exactly the same.
In general, if a storage solution claims to be "S3 compatible",
it should work with the <a href="https://github.com/concourse/s3-resource">Concourse S3 resource integration</a>.
But note that it may behave differently if interacting directly with the S3 API.
Defer to the documentation of your preferred blobstore solution
when setting up storage.</p>

1. Set up S3. With your AWS account, navigate to [the S3 console](https://aws.amazon.com/console/)
and sign up for S3. Follow the on-screen prompts.
Now you are ready for buckets!

<p class="note important">
<span class="note__title">Important</span>
AWS Root User:
When you sign up for the S3 service on Amazon,
the account with the email and password you use
is the AWS account root user.
As a best practice, you should not use the root user
to access and manipulate services.
Instead, use <a href="https://aws.amazon.com/iam/">AWS Identity and Access Management (IAM)</a>
to create and manage users.
For more information about how this works,
see the <a href="https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-set-up.html#create-an-admin">Amazon IAM guide</a>.
<br>
For simplicity, in the rest of this guide,
we will use the AWS root user
to show how a bucket may be set up and used with Platform Automation Toolkit.</p>


## Your first bucket

S3 stores data as objects within buckets.
An object is any file that can be stored on a file system.
Buckets are the containers for objects.
Buckets can have permissions for who can
create, write, delete, and see objects within that bucket.

1. Navigate to [the S3 console](https://aws.amazon.com/console/)
2. Click the "Create bucket" button
3. Enter a DNS-compliant name for your new bucket
    - This name must be unique across all of AWS S3 buckets
    and adhere to general URL guidelines.
    Make it something meaningful and memorable!
4. Enter the "Region" you want the bucket to reside in
5. Choose "Create"

This creates a bucket with the default S3 settings.
Bucket permissions and settings
can be set during bucket creation or changed afterwards.
Bucket settings can even be copied from other buckets you have.
For a detailed look at creating buckets
and managing initial settings, see
[Creating a bucket](https://docs.aws.amazon.com/AmazonS3/latest/userguide/create-bucket-overview.html).

## Bucket permissions

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

1. Navigate to [the S3 console](https://aws.amazon.com/console/).
2. Choose the name of the bucket you created in the previous step
3. In the top row, choose "Permissions"

In this tab,
you can set the various permissions
for an individual bucket.
For simplicity, in this guide, we will use public permissions
for Concourse to access the files.

1. Under the permissions tab for a bucket, choose **Public access settings**.
1. Select **Edit** to change the public access settings
1. Uncheck all boxes to allow public access.

In general, the credentials being used
to access an S3 compatible blobstore through Concourse
must have `Read` and `Write` permissions.
It is possible to use different user roles
with different credentials to separate which user can `Read`
objects from the bucket and which user can `Write` objects to the bucket.

<p class="note">
<span class="note__title">Note</span>
Amazon S3 provides many [permission settings for buckets](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-access-control.html).
Specific IAM users can have access and objects can have their own permissions. In addition, buckets can have their own custom policies.
See [Configuring ACLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/managing-acls.html).
Refer to your organization's security policy
to best set up your S3 bucket.</p>

## Object versions

By default, an S3 bucket will be unversioned.
An unversioned bucket will not allow different versions of the same object.
In order to take advantage of using an S3 bucket with Platform Automation Toolkit,
we will want to enable versioning. Enabling versioning is not required,
but versioning does make the process easier,
and will require less potential manual steps around naming updates to the new file
whenever they are changed.

1. Navigate to [the S3 console](https://aws.amazon.com/console/).
2. Choose the name of the bucket you created in the previous step.
3. Select the **Properties** tab.
4. Click the **Versioning** tile.
5. Select **Enable Versioning**"

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

## Storing files in S3

Any file that can be stored on a computer
can be stored on S3. S3 is especially good at storing large files as it is designed to scale with large amounts of data while still being durable and fast.

Platform Automation Toolkit users may want to store the following files in S3:

- `.pivotal` product files
- `.tgz` stemcell files
- `.ova` Operations Manager files
- `.zip` foundation exports

Platform Automation Toolkit users will likely **_NOT_** want to store the following in S3:

- `.yaml` configuration files - Git is better suited for this
- `secrets.yaml` environment and secret files - There are a number of ways
to handle these types of files, but they should not be stored in S3.
See [Using a secrets store to store credentials](../concepts/secrets-handling.md)
for information about working with these types of files.  

## Structuring your bucket

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
│   │   │     ubuntu-xenial.tgz
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

## Using a bucket

When using the [Concourse S3 Resource](https://github.com/concourse/s3-resource),
several configuration properties are available
for retrieving objects. The bucket name is required.

<p class="note">
<span class="note__title">Note</span>
For your Concourse to have access to your S3 bucket,
ensure that you have the appropriate firewall and networking settings
for your Concourse instance to
make requests to your bucket.
Concourse uses various "outside" resources
to perform certain jobs.
Ensure that Concourse can "talk" to your S3 bucket.</p>


## Reference resources pipeline

The [resources pipeline](../pipelines/resources.md)
may be used to download dependencies from Tanzu Network
and place them into a trusted S3 bucket.
The various `resources_types` use the [Concourse S3 Resource type](https://github.com/concourse/s3-resource)
and several Platform Automation Toolkit tasks to accomplish this.
The following is an S3-specific breakdown of these components
and where to find more information.

#### The download-product task

The [`download-product`](../tasks.md#download-product) task lets you download products from Tanzu Network.
If S3 properties are set in the [download config](../inputs-outputs.md#download-product-config),
these files can be placed into an S3 bucket.

If S3 configurations are set,
this task will perform a specific filename operation
that will prepend meta data to the filename.
If downloading the product `Example Product version 2.2.1` from Tanzu Network
where the product slug is `example-product` and the version is `2.2.1`,
when directly downloaded from Tanzu Network, the file may appear as:

```
product-2.2-build99.pivotal
```

Because Tanzu Network file names
do not always have the necessary metadata required by Platform Automation Toolkit,
the download product task will prepend the necessary information
to the filename before it is placed into the S3 bucket:

```
[example-product,2.2.1-build99]product-2.2-build99.pivotal
```

<p class="note important">
<span class="note__title">Important</span>
Do not change the meta information prepended by <code>download-product</code>.
This information is required
if using a <code>download-product</code> with a blobstore (i.e. AWS, GCS)
in order to properly parse product versions.
<br>
If placing a product file into an blobstore bucket manually,
ensure that it has the proper file name format;
opening bracket, the product slug, a single comma, the product's version, and finally, closing bracket.
There should be no spaces between the two brackets.
For example, for a product with slug of <code>product-slug</code> and version of <code>1.1.1<code>:
<br>
<code>
[product-slug,1.1.1]original-filename.pivotal
</code>
</p>

The [`download-product`](../tasks.md#download-product)
task lets you download products from an blobstore bucket if you define the `SOURCE` param.
The prefixed metadata added by `download-product` with `SOURCE: pivnet` is used to find the appropriate file.
This task uses the same [download-product config file](../inputs-outputs.md#download-product-config)
as `download-product` to ensure consistency
across what is `put` in the blobstore
and what is being accessed later.
`download-product` with `SOURCE: pivnet` and `download-product` with `SOURCE: s3|gcs|azure` are designed
to be used together.
The download product config should be different between the two tasks.

For complete information on this task
and how it works, see the [task reference](../tasks.md#download-product).

[//]: # ({% with path="../" %})
[//]: # (    {% include ".internal_link_url.md" %})
[//]: # ({% endwith %})
[//]: # ({% include ".external_link_url.md" %})
