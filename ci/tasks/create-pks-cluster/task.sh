#!/usr/bin/env bash

set -eux

chmod +x pks-cli/tkgi-*
mv pks-cli/tkgi-* pks

echo "Signing in to UAA..."
uaac target --skip-ssl-validation "https://api.pks.$DOMAIN":8443
secret="$(om --env "$ENV_FILE" \
  credentials \
  -p pivotal-container-service \
  --credential-reference '.properties.pks_uaa_management_admin_client' -format json | jq -r .secret)"
uaac token client get admin -s "$secret"

userExists="$(uaac user get platform-automation)"
if [[ "$userExists" == *"CF::UAA::NotFound: CF::UAA::NotFound"* ]]; then
  echo "Creating the platform-automation user in UAA..."
  uaac user add platform-automation --emails platform-automation@example.com -p super-secret-password
  uaac member add pks.clusters.admin platform-automation
else
  echo "platform-automation user is already created. Skipping..."
fi

./pks login -a "api.pks.$DOMAIN" -u platform-automation -p super-secret-password --skip-ssl-validation
cluster="$(./pks clusters)"
if [[ "$cluster" == *"$CLUSTER_NAME"* ]]; then
  echo "Cluster: $CLUSTER_NAME already exists. Done."
else
  echo "Creating new pks cluster:  $CLUSTER_NAME..."
  ./pks create-cluster "$CLUSTER_NAME" --plan small --external-hostname example.hostname

  echo "Waiting until cluster is created (this can take up to 30 minutes to complete)..."
  complete=$(./pks cluster "$CLUSTER_NAME")
  while [[ "$complete" != *"succeeded"* ]]; do
    echo "Cluster is still creating. Waiting for $SLEEP_INTERVAL..."
    sleep "$SLEEP_INTERVAL"
    complete=$(./pks cluster "$CLUSTER_NAME")
  done

  echo "Cluster: $CLUSTER_NAME has been created."
  exit 0
fi
