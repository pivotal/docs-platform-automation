#!/usr/bin/env bash
# code_snippet prepare-image-script start bash

cat /var/version && echo ""
set -eu

if [ -z "$CA_CERTS" ] && [ -z "$CA_CERT_FILES" ]; then
  { printf "Either/both CA_CERTS or CA_CERT_FILES is required"; } 2> /dev/null
  exit 1
fi

if [ -n "$CA_CERTS" ]; then
  echo 'Found certs in CA_CERTS'
  echo "${CA_CERTS}" > /usr/local/share/ca-certificates/custom.crt
fi

if [ -n "$CA_CERT_FILES" ]; then
  echo 'Found certs in CA_CERT_FILES'
  for cf in ${CA_CERT_FILES}
  do
    cat config/"$cf" >> /usr/local/share/ca-certificates/custom.crt
  done
fi

update-ca-certificates

# copy updated files for certs
rsync -al /etc/ssl/certs/ "$PWD"/platform-automation-image/rootfs/etc/ssl/certs
rsync -al /usr/local/share/ca-certificates/ "$PWD"/platform-automation-image/rootfs/usr/local/share/ca-certificates
rsync -al /usr/share/ca-certificates/ "$PWD"/platform-automation-image/rootfs/usr/share/ca-certificates

# code_snippet prepare-image-script end