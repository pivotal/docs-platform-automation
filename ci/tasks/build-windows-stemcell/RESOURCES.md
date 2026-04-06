# Resources for build-windows-stemcell Task

This document explains where the platform automation image and tasks are published, and how to use them in your pipeline.

## Image Resources

### binaries-image (Recommended)

The `binaries-image` is built in the CI pipeline (`build-binaries-image-combined` job) and includes:
- Packer 1.10.0 + vsphere plugin (added via `Dockerfile.binaries`)
- govc (VMware vSphere CLI)
- om, bosh, bbr, credhub, and other CLI tools

**Registry Location:**
```yaml
- name: binaries-image
  type: registry-image
  source:
    repository: ((concourse-team/dev_image_registry.dev_url))/internalpcfplatformautomation/platform-automation
    tag: testing
    username: ((concourse-team/dev_image_registry.username))
    password: ((concourse-team/dev_image_registry.password))
```

**When it's built:**
- Automatically built in `build-binaries-image-combined` job
- Triggered when CLI binaries are updated
- Tagged as `testing` for development use

### platform-automation-image (Alternative)

The full platform automation image is published to multiple locations:

**1. S3 Release Candidate:**
```yaml
- name: rc-image-s3
  type: s3-with-arn
  source:
    bucket: ((platform-automation/main/s3_with_role.buckets.release_candidate))
    regexp: platform-automation-image-(.*).tgz
```

**2. S3 Published (PivNet):**
```yaml
- name: platform-automation-image-s3
  type: s3-with-arn
  source:
    bucket: ((platform-automation/main/s3_with_role.buckets.pivnet_products))
    regexp: platform-automation-image-(.*).tgz
```

**3. Registry (TanzuNet Dev):**
```yaml
- name: image-tanzunet-dev
  type: registry-image
  source:
    repository: ((concourse-team/dev_image_registry.url))/platform-automation/platform-automation-image
    tag: develop
    username: ((concourse-team/dev_image_registry.username))
    password: ((concourse-team/dev_image_registry.password))
```

## Task Resources

### From Git Repository (Recommended)

The `build-windows-stemcell` task is in the `docs-platform-automation` repository:

```yaml
- name: docs-platform-automation
  type: git
  source:
    uri: https://github.com/pivotal/docs-platform-automation.git
    branch: develop
    # Or use your fork:
    # uri: git@github.com:your-org/docs-platform-automation.git
    # branch: your-branch
    # private_key: ((github-private-key))
```

**Task definitions:**

- `ci/tasks/build-windows-stemcell/task.yml` — git input name **`docs-platform-automation`** (recommended with repo clone).
- `tasks/build-windows-stemcell.yml` — git input name **`platform-automation-tasks`** (common when the tasks bundle is a separate resource or alias).

### From S3 (Alternative)

Tasks are also packaged and published to S3:

**1. S3 Release Candidate:**
```yaml
- name: rc-tasks-s3
  type: s3-with-arn
  source:
    bucket: ((platform-automation/main/s3_with_role.buckets.release_candidate))
    regexp: platform-automation-tasks-(.*).zip
```

**2. S3 Published (PivNet):**
```yaml
- name: platform-automation-tasks-s3
  type: s3-with-arn
  source:
    bucket: ((platform-automation/main/s3_with_role.buckets.pivnet_products))
    regexp: platform-automation-tasks-(.*).zip
```

## Example Pipeline Usage

### Option 1: Use binaries-image + Git (Recommended for Development)

```yaml
resources:
- name: docs-platform-automation
  type: git
  source:
    uri: https://github.com/pivotal/docs-platform-automation.git
    branch: develop

- name: binaries-image
  type: registry-image
  source:
    repository: ((concourse-team/dev_image_registry.dev_url))/internalpcfplatformautomation/platform-automation
    tag: testing
    username: ((concourse-team/dev_image_registry.username))
    password: ((concourse-team/dev_image_registry.password))

jobs:
- name: build-windows-stemcell
  plan:
  - get: docs-platform-automation
  - get: binaries-image
    trigger: true
  - task: build-windows-stemcell
    image: binaries-image
    file: docs-platform-automation/ci/tasks/build-windows-stemcell/task.yml
    params:
      # ... your params
```

### Option 2: Use Published Platform Automation Image

```yaml
resources:
- name: platform-automation-image
  type: s3
  source:
    bucket: my-platform-automation-bucket
    regexp: platform-automation-image-(.*).tgz
    # Or use registry-image with image-tanzunet-dev

- name: platform-automation-tasks
  type: s3
  source:
    bucket: my-platform-automation-bucket
    regexp: platform-automation-tasks-(.*).zip

jobs:
- name: build-windows-stemcell
  plan:
  - get: platform-automation-image
    params:
      unpack: true
  - get: platform-automation-tasks
    params:
      unpack: true
  - task: build-windows-stemcell
    image: platform-automation-image
    file: platform-automation-tasks/tasks/build-windows-stemcell.yml
    params:
      # ... your params
```

## Notes

1. **binaries-image** is the fastest option for development/testing as it's built frequently
2. **platform-automation-image** is the official release image, updated less frequently
3. The `build-windows-stemcell` task requires Packer to be in the image (now included in `Dockerfile.binaries`)
4. All images include `govc` which is required for post-build provisioning
