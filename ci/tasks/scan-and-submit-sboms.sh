#!/bin/bash
set -eux

VERSION="$(cat version/version)"
RELEASE_LINE="$(echo $VERSION | rev | cut -d'.' -f2- | rev)"

mkdir -p platform-automation-product
tar -xf packaged-product/artifacts*.tar.gz -C platform-automation-product

mkdir -p platform-automation-image
tar -xf platform-automation-product/platform-automation-image-$VERSION.tgz -C platform-automation-image
syft platform-automation-image -o cyclonedx-json=platform-automation-image-sbom
pa_image_sha=$(sha1sum platform-automation-product/platform-automation-image-$VERSION.tgz | cut -d' ' -f1)

mkdir -p vsphere-platform-automation-image
tar -xf platform-automation-product/vsphere-platform-automation-image-$VERSION.tar.gz -C vsphere-platform-automation-image
syft vsphere-platform-automation-image -o cyclonedx-json=platform-automation-vsphere-image-sbom
pa_vsphere_image_sha=$(sha1sum platform-automation-product/vsphere-platform-automation-image-$VERSION.tar.gz | cut -d' ' -f1)

cat << MANIFEST > manifest.yml
---
kind: tvs.tanzu.broadcom.com/build@1.0.0
build:
  component: "platform-automation"
  version: $VERSION
  release-line: $RELEASE_LINE
  tags: ["GA"]
  artifacts:
    - name: "platform-automation-task-image"
      version: $VERSION
      digest: $pa_image_sha
      kind: "ARCHIVE"
      detailed-kind: "oci image tarball"
      bom-for-scanner: "platform-automation-image-sbom"
    - name: "platform-automation-vsphere-image"
      version: $VERSION
      digest: $pa_vsphere_image_sha
      kind: "ARCHIVE"
      detailed-kind: "oci image tarball"
      bom-for-scanner: "platform-automation-vsphere-image-sbom"
MANIFEST

chmod +x tvs-cli/tvs-linux-amd64
./tvs-cli/tvs-linux-amd64 submit manifest.yml --verbose 