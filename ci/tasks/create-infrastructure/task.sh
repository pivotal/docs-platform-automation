#!/usr/bin/env bash

set -eux

terraform_path=$PWD/paving/$IAAS
deployment_path=$PWD/deployments/$DEPLOYMENT_NAME

commit() {
  cp "$terraform_path"/terraform.tfstate "$deployment_path"
  pushd "$deployment_path"
    git config --global user.name "platform-automation-bot"
    git config --global user.email "$PLATFORM_AUTOMATION_EMAIL"
    git add terraform.tfstate

    if [ -e "$terraform_path"/terraform-vars.yml ]; then
      cp "$terraform_path"/terraform-vars.yml "$deployment_path"
      git add terraform-vars.yml
    fi

    cat > env.yml <<EOL
# this file is generated by CI
target: $(om interpolate -c terraform-vars.yml --path /ops_manager_dns)
username: $OM_USERNAME
password: $OM_PASSWORD
decryption-passphrase: $OM_PASSWORD
skip-ssl-validation: true
connect-timeout: 60
EOL
    git add env.yml
    git commit -m "updated terraform state for $DEPLOYMENT_NAME & updated env.yml" || true
  popd
}

trap commit EXIT

cp "$deployment_path"/terraform.tfstate "$terraform_path" || true # not required on first try
cp "$deployment_path"/terraform.tfvars "$terraform_path"

cd "$terraform_path"

terraform version

terraform init

terraform refresh \
  -state terraform.tfstate \
  -var-file terraform.tfvars

terraform plan \
  -state terraform.tfstate \
  -out terraform.tfplan \
  -var-file terraform.tfvars

terraform apply \
  -state-out terraform.tfstate \
  -parallelism=5 \
  terraform.tfplan

terraform output -json stable_config_opsmanager > terraform-vars.yml
