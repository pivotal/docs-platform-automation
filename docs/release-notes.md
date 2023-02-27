<style>
    .md-typeset h2 {
        font-weight: bold;
    }
</style>

## v5.1.0
February 27, 2023

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.24.10 |
    | azure-cli | 2.39.0 |
    | bbr-cli | [1.9.38](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.9.38) |
    | bosh-cli | [v7.1.0](https://github.com/cloudfoundry/bosh-cli/releases/tag/v7.1.0) |
    | credhub | [2.9.9](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.9.9) |
    | gcloud-cli | 412.0.0 |
    | govc-cli | 0.30.0 |
    | om | 694a983454bf38737eb32bf348a6e54099c5618d-2022-10-24T10:50:20-06:00 |
    | winfs-injector | [0.21.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.21.0) |
    | gcloud-cli | 364.0.0 |
    | govc-cli | 0.27.1 |
    | om | a9865819e957ebd1512c9fb1af41ab4a4ff0e834-2021-11-11T06:57:05-07:00 |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.1.0" target="_blank">Download</a>


### Breaking Changes
- Platform Automation will now require Concourse 5.0+

- There's an additional docker image for vSphere only.
  Most of our users are on vSphere,
  and excluding other IaaS-specific resources for the image greatly reduces
  file size and security surface area.
  The original image continues to work with all IaaSs, including vSphere,
  but if you use our product on vSphere,
  we recommend switching over to the new image.
  The new image is named:
  `vsphere-platform-automation-image-5.0.0.tar.gz`.
  Note that the filename starts with `vsphere-`
  and uses the alternate file extension `.tar.gz`
  instead of `.tgz`.
  This is to avoid breaking existing globs and patterns.
  See the following (API Declaration Change) for more information.

    If you're getting our image with the Pivnet resource
    as documented in the How-to guides,
    the new `get` configuration would look like this:

    ```yaml
    - get: platform-automation-image
      resource: platform-automation
      params:
        globs: ["vsphere-platform-automation-image-*.tar.gz"]
        unpack: true
    ```  

- Change to API Declaration Notice:

    As of 5.0 we are considering the patterns necessary to specify our files
    on Tanzu Network part of our API.
    Specificially, we will consider it a breaking change
    if any of the following glob patterns for the Platform Automation Toolkit image and tasks
    fail to return a single match
    when used with the `pivnet-resource` and/or `download-product` task:
    
      - `platform-automation-image-*.tgz`             # all IaaSes image
      - `vsphere-platform-automation-image-*.tar.gz`  # vSphere only image
      - `platform-automation-tasks-*.zip`             # tasks


- The deprecated `download-product-s3` task has been removed.
  For the same functionality, please use [`download-product`][download-product]
  and specify the `s3` `source`.

- The [`download-product`][download-product] task
  will no longer copy files to the existing outputs.
  Rather, these files will be written directly.
  This speeds up `download-product` in general,
  especially in systems where space IO might be a constraint.

    This change _*requires*_ Concourse 5.0+.
    If using an older version of Concourse, this task will error.

### What's New
- The [`download-and-upload-product`][download-and-upload-product] task has been added.
  This advanced task optimizes the steps of downloading and uploading a product file to an Ops Manager.
  Before downloading, Ops Manager is checked to see if the product/stemcell has been uploaded already.
  If it has, the download and upload steps are skipped.
  There are no outputs on this task.
  At the moment, this task only supports downloading from Tanzu Network (Pivotal Network).
- The [`backup-product`][backup-product] and [`backup-director`][backup-director] tasks have been added.
  These tasks use [BOSH Backup and Restore][bbr]
  to backup artifacts which can be used to restore your director and products.
  Note, there is no task to automate restoring from a backup.
  Restore cannot be guaranteed to be idempotent, and therefore cannot be safely automated.
  See the [BBR docs][bbr-restore] for information on restoring from a backup.
- The [`backup-tkgi`][backup-tkgi] task has been added.
  This task is specific to the Tanzu Kubernetes Grid Integrated Edition(TKGI) product.
  It will backup the tile _and_ the TKGI clusters.

    To persist this backup to a blobstore, the blobstore resource can match the following regexes:

    - For TKGI tile: `product_*.tgz`
    - For the TKGI clusters: `*_clusters_*.tgz`

    !!! info "PKS CLI may be Temporarily Unavailable"
        During `backup-tkgi`, the PKS CLI is disabled.
        Due to the nature of the backup, some commands may not work as expected.

- [`apply-changes`][apply-changes] now supports the optional input `ERRAND_CONFIG_FILE`.
  If provided, `apply-changes` can enable/disable an errand for a particular run.
  To retrieve the default configuration of your product's errands,
  `om staged-config` can be used.
  The expected format for this errand config is as follows:

    ```yaml
    errands:
      sample-product-1:
        run_post_deploy:
          smoke_tests: default
          push-app: false
        run_pre_delete:
          smoke_tests: true
      sample-product-2:
        run_post_deploy:
          smoke_tests: default
    ```

- [`prepare-tasks-with-secrets`][prepare-tasks-with-secrets] will now inject a params block
  if one is not already present in the task.
- [`stage-configure-apply`][stage-configure-apply] now offers the ability to optionally upload and/or assign a stemcell.
  To upload a stemcell, provide a `stemcell` input as you would for [`upload-stemcell`][upload-stemcell].
  To assign a stemcell, provide an `assign-stemcell-config` input
  (this can be the same as your normal config, but must be mapped to this name in your `pipeline.yml`).

    If you wish to upload a stemcell, there are two new (optional) `params`:<br />
    - `FLOATING_STEMCELL`:
      this is equivalent to the `FLOATING_STEMCELL` param of [`upload-stemcell`][upload-stemcell].<br />
    - `UPLOAD_STEMCELL_CONFIG_FILE`:
      this is equivalent to the `CONFIG_FILE` param of [`upload-stemcell`][upload-stemcell].<br />

    If you wish to assign a specific stemcell to the staged product,
    you need to provide the `assign-stemcell-config` input
    and define the `ASSIGN_STEMCELL_CONFIG_FILE` param.
    This param is equivalent to the `CONFIG_FILE` param of [`assign-stemcell`][assign-stemcell].

- [`run-bosh-errand`][run-bosh-errand] task has been added.
  This task runs a specified BOSH errand directly on the BOSH director
  by tunneling through the Ops Manager.
  As such, any errand run in this way does not have visibility within the Ops Manager.
  *Please note this is an advanced feature, and should be used at your own discretion.* 

### Deprecation Notices
- In future _major_ versions of Platform Automation, the [`credhub-interpolate`][credhub-interpolate] task will be removed.
  Please use the [`prepare-tasks-with-secrets`][prepare-tasks-with-secrets] task in its place.

### Known Issues
- When using the task [`backup-tkgi`][backup-tkgi] behind a proxy
  the values for `no_proxy` can affect the ssh (though jumpbox) tunneling.
  When the task invokes the `bbr` CLI, an environment variable (`BOSH_ALL_PROXY`) has been set,
  this environment variable tries to honor the `no_proxy` settings.
  The task's usage of the ssh tunnel requires the `no_proxy` to not be set.
  
    If you experience an error, such as an SSH connection refused or connection timeout,
    try setting the `no_proxy: ""` as `params` on the task.
    
    For example,
    
    ```yaml
    - task: backup-tkgi
      file: platform-automation-tasks/tasks/backup-tkgi.yml
      params:
        no_proxy: ""
    ```