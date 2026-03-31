#!/usr/bin/env bash

set -eu

git clone deployments deployments-updated
path=deployments-updated/platform-automation/"$IAAS"/state
mkdir -p "$path"
cp generated-state/state.yml "$path"/state.yml
cd deployments-updated

git add -A
git commit -m "[skip-commit-ruleset] adding state file for $IAAS" || true
