<style>
    .md-typeset h2 {
        font-weight: bold;
    }
</style>

{% include "./.opsman_filename_change_note.md" %}

!!! warning "Azure Updating to 2.5"
     Ops Manager will be removing the necessity to provide availability zones for azure.
     If your `director.yml`(see [`staged-director-config`][staged-director-config])
     has a block like the following in the networks section:
     ```yaml
        availability_zone_names:
        - "null"
     ```
     your deployment will have the following error:
     ```json
     {"errors":["Availability zones cannot find availability zone with name null"]}
     ```
     To fix this error, please remove the `availability_zone_names` section from your azure config, or re-run
     [`staged-director-config`][staged-director-config] to update your `director.yml`.

## v5.0.25
June 15, 2023

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.27.153 |
    | azure-cli | 2.49.0 |
    | bbr-cli | [1.9.46](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.9.46) |
    | bosh-cli | [v7.2.3](https://github.com/cloudfoundry/bosh-cli/releases/tag/v7.2.3) |
    | credhub | [2.9.16](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.9.16) |
    | gcloud-cli | 435.0.1 |
    | govc-cli | 0.30.4 |
    | om | 45876ef5954ddb419cd88126d77b4e8ebb2ca554-2023-05-03T17:38:11-07:00 |
    | winfs-injector | [0.22.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.22.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.25" target="_blank">Download</a>

### Maintenance Release
- Update Platform Automation Toolkit to use Ubuntu Jammy-based Paketo buildpack images


## v5.0.24
May 5, 2023

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.24.10 |
    | azure-cli | 2.39.0 |
    | bbr-cli | [1.9.44](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.9.44) |
    | bosh-cli | [v7.2.3](https://github.com/cloudfoundry/bosh-cli/releases/tag/v7.2.3) |
    | credhub | [2.9.14](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.9.14) |
    | gcloud-cli | 429.0.0 |
    | govc-cli | 0.30.4 |
    | om | 45876ef5954ddb419cd88126d77b4e8ebb2ca554-2023-05-03T17:38:11-07:00 |
    | winfs-injector | [0.22.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.22.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.24" target="_blank">Download</a>

### Bug Fixes
- Update govc to v0.30.4
- Delete all python files from vsphere-only docker image


## v5.0.23
January 4, 2023

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

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.23" target="_blank">Download</a>

### Bug Fixes
- bump bundled iso-replicator binary to 0.13.0, compiled with Golang 1.19.4


## v5.0.22
October 24, 2022

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.24.10 |
    | azure-cli | 2.39.0 |
    | bbr-cli | [1.9.38](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.9.38) |
    | bosh-cli | [v7.0.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v7.0.1) |
    | credhub | [2.9.6](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.9.6) |
    | gcloud-cli | 406.0.0 |
    | govc-cli | 0.29.0 |
    | om | 694a983454bf38737eb32bf348a6e54099c5618d-2022-10-24T10:50:20-06:00 |
    | winfs-injector | [0.21.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.21.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.22" target="_blank">Download</a>

### Bug Fixes
    Bump versions of included binaries


## v5.0.21
March 21, 2022

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.22.77 |
    | azure-cli | 2.34.1 |
    | bbr-cli | [1.9.26](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.9.26) |
    | bosh-cli | [v6.4.17](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.17) |
    | credhub | [2.9.3](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.9.3) |
    | gcloud-cli | 377.0.0 |
    | govc-cli | 0.27.4 |
    | om | 2aeff1d15cfe3e192567098afc107d718110b33f-2022-03-07T14:07:08-05:00 |
    | winfs-injector | [0.21.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.21.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.21" target="_blank">Download</a>

### Bug Fixes
- Bump versions of included binaries


## v5.0.20
January 5, 2022

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.22.28 |
    | azure-cli | 2.32.0 |
    | bbr-cli | [1.9.21](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.9.21) |
    | bosh-cli | [v6.4.10](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.10) |
    | credhub | [2.9.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.9.1) |
    | gcloud-cli | 367.0.0 |
    | govc-cli | 0.27.2 |
    | om | 87f12ad07a994a2946c2a04303d98dc589e67744-2021-11-30T14:26:51-08:00 |
    | winfs-injector | [0.21.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.21.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.20" target="_blank">Download</a>

### Bug Fixes
- CVE update to container image.
Resolves [USN-5199-1](https://ubuntu.com/security/notices/USN-5199-1),
an issue related to python3.6.
- CVE update to container image.
Resolves [USN-5189-1](https://ubuntu.com/security/notices/USN-5189-1),
an issue related to glib2.0.


## v5.0.19
November 11, 2021

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.22.3 |
    | azure-cli | 2.30.0 |
    | bbr-cli | [1.9.18](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.9.18) |
    | bosh-cli | [v6.4.7](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.7) |
    | credhub | [2.9.1](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.9.1) |
    | gcloud-cli | 364.0.0 |
    | govc-cli | 0.27.1 |
    | om | a9865819e957ebd1512c9fb1af41ab4a4ff0e834-2021-11-11T06:57:05-07:00 |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.19" target="_blank">Download</a>

### Bug Fixes
- CVE update to container image.
  Resolves [USN 5133-1](https://ubuntu.com/security/notices/USN-5133-1),
  an issue related to ICU crashing


## v5.0.18
September 23, 2021

### Bug Fixes
- Fixed an issue on the `tasks/configure-opsman.sh`, which had a line that printed `om` help messages.
- CVE update to container image.
  Resolves [USN 5089-1](https://ubuntu.com/security/notices/USN-5089-1),
  an issue related to expiring ca certificate.
- CVE update to container image.
  Resolves [USN 5079-3](https://ubuntu.com/security/notices/USN-5079-3),
  an issue related to curl.
- CVE update to container image.
  Resolves [USN-5080-1](https://ubuntu.com/security/notices/USN-5080-1),
  an issue related to libgcrypt.
- CVE update to container image.
  Resolves [USN-5079-1](https://ubuntu.com/security/notices/USN-5079-1),
  an issue related to curl.
- CVE update to container image.
  Resolves [USN-5076-1](https://ubuntu.com/security/notices/USN-5076-1),
  an issue related to git.
- CVE update to container image.
  Resolves [USN-5051-3](https://ubuntu.com/security/notices/USN-5051-3),
  an issue related to OpenSSL.
- CVE update to container image.
  Resolves [USN-5051-1](https://ubuntu.com/security/notices/USN-5051-1),
  an issue related to OpenSSL.
- CVE update to container image.
  Resolves [USN-3809-2](https://ubuntu.com/security/notices/USN-3809-2),
  an issue related to OpenSSH.

## v5.0.17
August 2, 2021

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.20.11 |
    | azure-cli | 2.26.1 |
    | bbr-cli | [1.9.11](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.9.11) |
    | bosh-cli | [v6.4.4](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.4) |
    | credhub | [2.9.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.9.0) |
    | gcloud-cli | 350.0.0 |
    | govc-cli | 0.26.0 |
    | om | c9895b73b2b111a24b7c4ae787a7603d7f8a2723-2021-08-01T20:26:31-06:00 |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.17" target="_blank">Download</a>

### Bug Fixes
- The `om` CLI has been explicitly requesting `opaque` tokens.
  This was an unintentional and incidental change;
  previously it used `jwt`,
  the token format UAA provides by default.
  The `opaque` token may have been contributing to
  a hard-to-reproduce issue in a customer environment,
  so we're explicitly switching back to `jwt` tokens.
- CVE update to container image.
  Resolves [USN 5021-1](https://ubuntu.com/security/notices/USN-5021-1),
  an issue related to libcurl.
- CVE update to container image.
  Resolves [USN 4991-1](https://ubuntu.com/security/notices/USN-4991-1),
  an issue related to libxml2.


## v5.0.16
June 17, 2021

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.19.96 |
    | azure-cli | 2.25.0 |
    | bbr-cli | [1.9.7](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.9.7) |
    | bosh-cli | [v6.4.4](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.4) |
    | credhub | [2.9.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.9.0) |
    | gcloud-cli | 345.0.0 |
    | govc-cli | 0.26.0 |
    | om | f0370bb68d212b136c1d673684c36bd57173665c-2021-06-17T08:25:19-06:00 |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.16" target="_blank">Download</a>

### Features
- When creating an Ops Manager VM on Vsphere, the disk size can be set via the configuration file to sizes larger than the default of 160 (GB).

    ```yaml
    ---
      opsman-configuration:
        vsphere:
          disk_size: 200
          vm_name: ops-manager-vm
          cpu: 4
          memory: 16
          disk_type: thin
          dns: 8.8.8.8
          gateway: 192.168.10.1
          hostname: ops-manager.example.com
          netmask: 255.255.255.192
          network: example-virtual-network
          ntp: ntp.ubuntu.com
          private_ip: 10.0.0.10
          ssh_public_key: ssh-rsa ......
          vcenter:
            ca_cert: cert
            datacenter: example-dc
            datastore: example-ds-1
            folder: /example-dc/vm/Folder
            url: vcenter.example.com
            username: ((vcenter-username))
            password: ((vcenter-password))
            resource_pool: /example-dc/host/example-cluster/Resources/example-pool
    ```

- When creating or updating an Ops Manager VM on Azure, you can set an optional tags argument for creating tags on the Ops Manager VM.

    ```yaml
    ---
    opsman-configuration:
      azure:
        tags: Key=Value
        vm_name: ops-manager-vm
        boot_disk_size: 200
        tenant_id: 3e52862f-a01e-4b97-98d5-f31a409df682
        subscription_id: 90f35f10-ea9e-4e80-aac4-d6778b995532
        client_id: 5782deb6-9195-4827-83ae-a13fda90aa0d
        client_secret: ((opsman-client-secret))
        location: westus
        resource_group: res-group
        storage_account: opsman
        ssh_public_key: ssh-rsa AAAAB3NzaC1yc2EAZ... 
        subnet_id: /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.Network/virtualNetworks/<VNET>/subnets/<SUBNET>
        private_ip: 10.0.0.3
    ```
  
### Bug Fixes
- CVE update to container image. Resolves [USN-4891-1](https://ubuntu.com/security/notices/USN-4891-1). The CVEs are related to vulnerabilities with `libssl`.
- CVE update to container image. Resolves [USN-4968-1](https://ubuntu.com/security/notices/USN-4968-1). The CVEs are related to vulnerabilities with `liblz4-1`.
- CVE update to container image. Resolves [USN-4906-1](https://ubuntu.com/security/notices/USN-4906-1) and [USN-4990-1](https://ubuntu.com/security/notices/USN-4990-1). The CVEs are related to vulnerabilities with `libnettle6`.
- CVE update to container image. Resolves [USN-4898-1](https://ubuntu.com/security/notices/USN-4898-1). The CVEs are related to vulnerabilities with `curl` and related libraries.
- CVE update to container image. Resolves [USN-4764-1](https://ubuntu.com/security/notices/USN-4764-1). The CVEs are related to vulnerabilities with `libglib2.0-0`.
- CVE update to container image. Resolves [USN-4761-1](https://ubuntu.com/security/notices/USN-4761-1). The CVEs are related to vulnerabilities with `git`.


## v5.0.15
March 9, 2021

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.19.23 |
    | azure-cli | 2.20.0 |
    | bbr-cli | [1.9.1](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.9.1) |
    | bosh-cli | [v6.4.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.1) |
    | credhub | [2.9.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.9.0) |
    | gcloud-cli | 330.0.0 |
    | govc-cli | v0.24.0 |
    | om | 6516c1a327f7bb7ede88c857e5b4d0d58f27f5bc-2021-01-26T10:53:54-07:00 |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.15" target="_blank">Download</a>

### Bug Fixes
- CVE update to container image. Resolves [USN-4738-1](https://ubuntu.com/security/notices/USN-4738-1). The CVEs are related to vulnerabilities with `libssl`.
- CVE update to container image. Resolves [USN-4754-1](https://ubuntu.com/security/notices/USN-4754-1). The CVEs are related to vulnerabilities with `python` and related libraries.
- CVE update to container image. Resolves [USN-4759-1](https://ubuntu.com/security/notices/USN-4759-1). The CVEs are related to vulnerabilities with `libglib2.0-0`.
- CVE update to container image. Resolves [USN-4760-1](https://ubuntu.com/security/notices/USN-4760-1). The CVEs are related to vulnerabilities with `libzstd` and related libraries.


## v5.0.14
February 25, 2021

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.19.7 |
    | azure-cli | 2.19.1 |
    | bbr-cli | [1.9.1](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.9.1) |
    | bosh-cli | [v6.4.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.1) |
    | credhub | [2.9.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.9.0) |
    | gcloud-cli | 327.0.0 |
    | govc-cli | v0.24.0 |
    | om | 6516c1a327f7bb7ede88c857e5b4d0d58f27f5bc-2021-01-26T10:53:54-07:00 |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.14" target="_blank">Download</a>

### Bug Fixes
- CVE update to container image. Resolves [USN-4719-1](https://ubuntu.com/security/notices/USN-4719-1).


## v5.0.13
January 15, 2021

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.18.215 |
    | azure-cli | 2.17.1 |
    | bbr-cli | [1.9.1](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.9.1) |
    | bosh-cli | [v6.4.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.1) |
    | credhub | [2.9.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.9.0) |
    | gcloud-cli | 323.0.0 |
    | govc-cli | v0.24.0 |
    | om | 39fd21c57e46588e76bb07826a2d8809e29382e9-2021-01-12T08:23:20-07:00 |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-4.4.19" target="_blank">Download</a>

### Bug Fixes
- Use [`pip` documented](https://pip.pypa.io/en/stable/installing/) method for installing it on the container image
- With new GCP practices, defining a [`hostname`](https://cloud.google.com/compute/docs/instances/custom-hostname-vm) on the VM can be required.
  When creating an Ops Manager VM on GCP, the attribute can be set via the configuration file.
  
    ```yaml
    ---
      opsman-configuration:
        gcp:
          boot_disk_size: 100
          custom_cpu: 4
          custom_memory: 16
          gcp_service_account: ((service_account_key))
          project: ((project))
          public_ip: ((ops_manager_public_ip))
          region: ((region))
          ssh_public_key: ((ops_manager_ssh_public_key))
          tags: ((ops_manager_tags))
          vm_name: ((environment_name))-ops-manager-vm
          vpc_subnet: ((management_subnet_name))
          zone: ((availability_zones.0))
          hostname: testing.some.domain
    ```

## v5.0.12
January 5, 2021

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.18.208 |
    | azure-cli | 2.17.1 |
    | bbr-cli | [1.9.0](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.9.0) |
    | bosh-cli | [v6.4.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.1) |
    | credhub | [2.9.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.9.0) |
    | gcloud-cli | 321.0.0 |
    | govc-cli | v0.24.0 |
    | om | dc7ecb856d9d6e8a5538512922e688bd337ab246-2021-01-04T09:19:13-07:00 |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |


### Bug Fixes
- CVE update to container image. Resolves [USN-4672-1](https://ubuntu.com/security/notices/USN-4672-1).
  The CVEs are related to vulnerabilities with `unzip` and related libraries.
- CVE update to container image. Resolves [USN-4667-1](https://ubuntu.com/security/notices/USN-4667-1).
  The CVEs are related to vulnerabilities with `apt` and related libraries.
- CVE update to container image. Resolves [USN-4665-1](https://ubuntu.com/security/notices/USN-4665-1).
  The CVEs are related to vulnerabilities with `curl` and related libraries.
- CVE update to container image. Resolves [USN-4662-1](https://ubuntu.com/security/notices/USN-4662-1).
  The CVEs are related to vulnerabilities with `libssl` and related libraries.
- CVE update to container image. Resolves [USN-4677-1](https://ubuntu.com/security/notices/USN-4677-1).
  The CVEs are related to vulnerabilities with `p11` and related libraries.


## v5.0.11

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.18.189 |
    | azure-cli | 2.15.1 |
    | bbr-cli | [1.8.1](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.8.1) |
    | bosh-cli | [v6.4.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.1) |
    | credhub | [2.8.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.8.0) |
    | gcloud-cli | 319.0.0 |
    | govc-cli | 0.23.0 |
    | om | acfd93675b65c8ca8a7f584cd53796d09e5fc88b-2020-12-03T07:19:52-07:00 |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

### Features
- [`configure-opsman`][configure-opsman] task can now configure the UAA token expirations and timeouts.
   
   ```yaml
   tokens-expiration:
     access_token_expiration: 10
     refresh_token_expiration: 10
     session_idle_timeout: 10
   ```

### Bug Fixes
- [`update-runtime-config`][update-runtime-config] task has the `releases` input as optional.
  When looking for `releases`, if the input wasn't there then the task would fail.
  A check has been added to ensure the input is there.
- With long-running tasks (using `om` commands),
  sometimes the authentication token would expire.
  If possible the token will be refreshed.
  This should help with HTTP retries.
- CVE update to container image. Resolves [USN-4608-1](https://ubuntu.com/security/notices/USN-4608-1).
  The CVEs are related to vulnerabilities with `ca-certificates` and related libraries.
- CVE update to container image. Resolves [USN-4635-1](https://ubuntu.com/security/notices/USN-4635-1).
  The CVEs are related to vulnerabilities with `krb5` and related libraries.

## v5.0.10
November 24, 2020

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.18.184 |
    | azure-cli | 2.15.1 |
    | bbr-cli | [1.8.1](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.8.1) |
    | bosh-cli | [v6.4.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.1) |
    | credhub | [2.8.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.8.0) |
    | gcloud-cli | 319.0.0 |
    | govc-cli | 0.23.0 |
    | om | 3a7d703bacb004220450d5984b01a5ea6ebe5087-2020-11-23T14:34:44-07:00 |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

### Bug Fixes
- Fixes an issue where `stemcell-heavy` in `download-product` had a regression with boolean values.

## v5.0.9
November 19, 2020

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.18.180 |
    | azure-cli | 2.15.0 |
    | bbr-cli | [1.8.1](https://github.com/cloudfoundry-incubator/bosh-backup-and-restore/releases/tag/v1.8.1) |
    | bosh-cli | [v6.4.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.1) |
    | credhub | [2.8.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.8.0) |
    | gcloud-cli | 319.0.0 |
    | govc-cli | 0.23.0 |
    | om | d424cdfe525f3d9ec4f7b6995c160d7b80c4a6f1-2020-11-18T09:51:49-07:00 |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.9" target="_blank">Download</a>

### Bug Fixes
- The `backup` scripts did not have the correct command line options to compress the tarball.
  It is still a valid tarball, just not compressed.
  This has been fixed by changing `tar -cvf` to `tar -zcvf`.
- [`prepare-tasks-with-secrets`][prepare-tasks-with-secrets] could not be used with other tasks.
  For example, if you had written custom tasks.
  The `TASK_PATH` was added, so custom paths of tasks could be prepared, too.
- [`stage-configure-apply`][stage-configure-apply] was missing the ability to configure errands.
  We've added the `ERRAND_CONFIG_FILE` parameter.
- [`stage-configure-apply`][stage-configure-apply] was using the incorrect path relative to the input.
  It was using `config` instead of `assign-stemcell-config`.

## v5.0.7
October 23, 2020

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.18.163 |
    | azure-cli | 2.13.0 |
    | bbr-cli | 1.8.0 |
    | bosh-cli | [v6.4.1](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.1) |
    | credhub | [2.8.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.8.0) |
    | gcloud-cli | 315.0.0 |
    | govc-cli | 0.23.0 |
    | om | [6.4.2](https://github.com/pivotal-cf/om/releases/tag/6.4.2) |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.7" target="_blank">Download</a>

### Bug Fixes
- CVE update to container image. Resolves [USN-4581-1](https://usn.ubuntu.com/4581-1/).
  The CVEs are related to vulnerabilities with `python3.6` and related libraries.
  This affects the all IAAS container images only.
- CVE update to container image. Resolves [USN-4601-1](https://usn.ubuntu.com/4601-1/).
  The CVEs are related to vulnerabilities with `python3-pip` and related libraries.
  This affects the all IAAS container images only.

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

## v5.0.6
October 14, 2020

!!! note "Updates to CLI versions"
    We've now updated our list of CLI versions.
    It includes the supported IAAS CLIs.

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | aws-cli | 1.18.157 |
    | azure-cli | 2.13.0 |
    | bosh-cli | [6.4.0](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.0) |
    | credhub | [2.8.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.8.0) |
    | gcloud-cli | 314.0.0 |
    | govc-cli | 0.23.0 |
    | om | [6.4.1](https://github.com/pivotal-cf/om/releases/tag/6.4.1) |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.6" target="_blank">Download</a>

### Bug Fixes
- Do to a release packaging issue,
  the previous patch version had issues invoking `openstack` CLI.
  This release ensures this has been fixed.
  We've also added further release testing to ensure it doesn't happen again.
- [`download-and-upload-product`][download-and-upload-product] did not upload the stemcell as expected.
  The task now properly uploads the stemcell if `stemcell-iaas`
  is provided in the config file. 

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

## v5.0.5
October 9, 2020

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | om | [6.4.1](https://github.com/pivotal-cf/om/releases/tag/6.4.1) |
    | bosh-cli | [v6.4.0](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.0) |
    | credhub | [2.8.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.8.0) |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.5" target="_blank">Download</a>

### Bug Fixes
- The "bug fixes" for collections in `om` 6.1.2+
  were causing unexpected issues in some tiles.
  The collection work has been reverted
  to its original functionality.
- [`pending-changes`][check-pending-changes] and [`stage-configure-apply`][stage-configure-apply]
  would always fail if a product is unconfigured, new, or missing a stemcell,
  regardless of whether `ALLOW_PENDING_CHANGES` was set.
  This has been fixed. `pending-changes` will only fail if `ALLOW_PENDING_CHANGES: false`.
- [`stage-product`][stage-product] and [`stage-configure-apply`][stage-configure-apply] 
  will now accept `latest` as the `product-version`
  if you are providing a `CONFIG_FILE`/`STAGE_PRODUCT_CONFIG_FILE`.
  This fixes an issue that required users to update their config file
  every time a new version was available on Ops Manager.
- [`stage-configure-apply`][stage-configure-apply] will now treat the `product` input
  as truly optional if `CONFIG_FILE` is provided. 

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

## v5.0.4
Released October 2, 2020

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | om | [6.3.0](https://github.com/pivotal-cf/om/releases/tag/6.3.0) |
    | bosh-cli | [v6.4.0](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.0) |
    | credhub | [2.8.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.8.0) |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.4" target="_blank">Download</a>

### Bug Fixes
- The [`download-and-upload-product`][download-and-upload-product] task did not provide the option to leave the stemcell floating.
  A new param (`FLOATING_STEMCELL`) allows floating for a stemcell to be set.
  Its default value is set to `true`.
  The expectation is to affect one product, not all products.
- The [`backup-tkgi`][backup-tkgi] task had a misnamed param.
  `$deployment_name` has been renamed to `$DEPLOYMENT_NAME` as was necessary.
- CVE update to container image. Resolves [USN-4512-1](https://usn.ubuntu.com/4512-1/).
The CVEs are related to vulnerabilities with `util-linux` and related libraries.
- CVE update to container image. Resolves [USN-4504-1](https://usn.ubuntu.com/4504-1/).
The CVEs are related to vulnerabilities with `libssl` and related libraries.

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

## v5.0.3
September 15, 2020

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | om | [6.3.0](https://github.com/pivotal-cf/om/releases/tag/6.3.0) |
    | bosh-cli | [v6.4.0](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.0) |
    | credhub | [2.8.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.8.0) |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.3" target="_blank">Download</a>

### Bug Fixes
- There was an issue with how `om` retrieved credentials
  within the new heuristic logic for collections updates.
  In particular, this impacted the upgrade from TAS 2.6 to 2.7,
  and caused `configure-product` to fail.
  The error message looked something like this:
  
    ```bash
    2020/09/01 06:35:54 could not execute "configure-product": failed to configure product: failed to associate guids for property ".properties.credhub_internal_provider_keys" because:
    request failed: unexpected response from /api/v0/deployed/products/cf-6bdb4038d37667f9f424/credentials/.properties.credhub_internal_provider_keys[0].key:
    HTTP/1.1 404 Not Found
    ...more HTTP headers...
    ```

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

## v5.0.2
September 9, 2020

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | om | [6.2.0](https://github.com/pivotal-cf/om/releases/tag/6.2.0) |
    | bosh-cli | [v6.4.0](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.0) |
    | credhub | [2.8.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.8.0) |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.2" target="_blank">Download</a>

### Bug Fixes
- Releasing the vSphere only-image, sorry about that in v5.0.1.
- Bump the CLIs for `om`, `credhub`, and `winfs-injector`.

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

## v5.0.1
Released September 4, 2020

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | om | [6.1.0](https://github.com/pivotal-cf/om/releases/tag/6.1.0) |
    | bosh-cli | [v6.4.0](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.0) |
    | credhub | [2.7.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.7.0) |
    | winfs-injector | [0.18.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.18.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.1" target="_blank">Download</a>

!!! warning "Removed from Releases"
    There was a regression introduced in v5.0.1.
    It will be removed form Tanzu Network.
    Please use v5.0.2 instead.

### Bug Fixes
- tl;dr: If you have experienced the following error with the [`create-vm`][create-vm] task this is fixed.
  
    ```bash
    creating the new opsman vm
    Using gcp...
    Error: unexpected error: could not marshal image file: yaml: unmarshal errors:
      line 6: cannot unmarshal !!map into string
    ```
  
    With GCP OpsManager, the image YAML file format includes a new key.
    
    The original format of the image YAML was:
    
    ```yaml
    ---
    us: ops-manager-us/pcf-gcp-2.9.9-build.164.tar.gz
    eu: ops-manager-us/pcf-gcp-2.9.9-build.164.tar.gz
    asia: ops-manager-us/pcf-gcp-2.9.9-build.164.tar.gz
    ```
    
    The new format includes the `image` key:
    
    ```yaml
    ---
    us: ops-manager-us/pcf-gcp-2.9.10-build.177.tar.gz
    eu: ops-manager-us/pcf-gcp-2.9.10-build.177.tar.gz
    asia: ops-manager-us/pcf-gcp-2.9.10-build.177.tar.gz
    image:
     name: ops-manager-2-9-10-build-177
     project: pivotal-ops-manager-images
    ```
    
    This patch ignores this value, where previously it would've not been able to parse it.

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

## v5.0.0
Released September 2, 2020

??? info "CLI Versions"

    | Name | version |
    |---|---|
    | om | [6.2.0](https://github.com/pivotal-cf/om/releases/tag/6.2.0) |
    | bosh-cli | [v6.4.0](https://github.com/cloudfoundry/bosh-cli/releases/tag/v6.4.0) |
    | credhub | [2.8.0](https://github.com/cloudfoundry-incubator/credhub-cli/releases/tag/2.8.0) |
    | winfs-injector | [0.19.0](https://github.com/pivotal-cf/winfs-injector/releases/tag/0.19.0) |

    The full Docker image-receipt: <a href="https://platform-automation-release-candidate.s3-us-west-2.amazonaws.com/image-receipt-5.0.0" target="_blank">Download</a>

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