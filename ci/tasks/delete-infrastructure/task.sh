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

  git commit -m "[skip-commit-ruleset] deleted infrastructure for $IAAS" || true
popd
}

trap commit EXIT

cp "$deployment_path"/terraform.tfstate "$terraform_path"
cp "$deployment_path"/terraform.tfvars "$terraform_path"

if [[ "$IAAS" == "azure" ]]; then
  eval "$(python3 "$PWD/docs-platform-automation/ci/scripts/azure-cert-to-pfx.py" --tfvars "$terraform_path/terraform.tfvars")"
fi

cd "$terraform_path"

terraform init

terraform destroy \
  -auto-approve \
  -var-file=terraform.tfvars \
  -state=terraform.tfstate
