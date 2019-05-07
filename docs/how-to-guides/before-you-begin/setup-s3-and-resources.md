# Before you Begin: Setup s3 and Reference Resources

Platform Automation uses 
file artifacts that are too large to store in git.
The recommended way to store these files
is in a Amazon s3 compatible object store,
commonly referred to as simply "s3".

In this guide,
you will learn 
how to set up s3 buckets,
how bucket permissions work,
what we can store in a bucket,
and how a pipeline may be set up
to retrieve and store objects in s3. 

## Pre-requisites

#### Minio

We will be using [Minio][minio],
a popular open source s3 object store.
Ensure that the [Minio server and Minio client][minio-download] 
are both installed on your machine.

#### Concourse CI

To build and use the reference resources,
we will need a running Concourse.
TODO: Link to something about how to pave IaaS

#### Concourse CLI

Ensure that you have the `fly` tool installed by running
```bash
fly -v
```
This should show you the version of `fly` you have.
If you do not have this tool, 
navigate to your Concourse instance in your browser
and download your OS's fly tool.
 
## Your first Bucket

First, let's create a folder for Minio to run in.
This folder will be used by Minio to store file objects.

```bash
mkdir ~/workspace/my-minio
```

In a terminal,
start the minio server with the following command:

```bash
minio server ~/workspace/my-minio
```

Minio by default uses port 9000.


## Bucket Permissions

## User  Permissions

## What could be stored in s3

## Mention Versioning

## Reference Resources - usefulness, setting up resources using s3

{% with path="../" %}
    {% include ".internal_link_url.md" %}
{% endwith %}
{% include ".external_link_url.md" %}
