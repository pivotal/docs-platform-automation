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
     | bosh-cli | [v7.1.3](https://github.com/cloudfoundry/bosh-cli/releases/tag/v7.1.3) |
     | credhub | [2.9.11](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.9.11) |
     | gcloud-cli | 419.0.0 |
     | govc-cli | 0.30.2 |
     | om | 2ba733630d765e1b41e815ce1b49e825da2c192b-2023-02-24T11:33:19-07:00 |
     | winfs-injector | [0.21.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.21.0) |
         
    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.1.0" target="_blank">Download</a>

### What's New
- Added new How-to Guide about [Rotating Certificate Authority][rotating-certificate-authority]. 
  This how-to-guide shows you how to write a pipeline for rotating the certificate authority on an existing Ops Manager. 
- The following additional tasks have been added to help with rotating certificate authorities:
    * [`activate-certificate-authority`][activate-certificate-authority]
    * [`configure-new-certificate-authority`][configure-new-certificate-authority]
    * [`delete-certificate-authority`][delete-certificate-authority]
    * [`generate-certificate`][generate-certificate]
    * [`regenerate-certificates`][regenerate-certificates]
      
{% include ".internal_link_url.md" %}
{% include ".external_link_url.md" %}