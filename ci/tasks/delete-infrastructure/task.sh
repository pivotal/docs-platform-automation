#!/usr/bin/env bash

set -eux

terraform_path="$PWD"/paving/"$IAAS"
deployment_path="$PWD"/deployments/"$DEPLOYMENT_NAME"

commit() {
cp "$terraform_path"/terraform.tfstate "$deployment_path"
pushd "$deployment_path"
  git config --global user.name "platform-automation-bot"
  git config --global user.email "$PLATFORM_AUTOMATION_EMAIL"
  git add terraform.tfstate

  git commit -m "deleted infrastructure for $IAAS" || true
popd
}

trap commit EXIT

cp "$deployment_path"/terraform.tfstate "$terraform_path"
cp "$deployment_path"/terraform.tfvars "$terraform_path"

cd "$terraform_path"

terraform init

terraform destroy \
  -auto-approve \
  -var-file=terraform.tfvars \
  -state=terraform.tfstate
