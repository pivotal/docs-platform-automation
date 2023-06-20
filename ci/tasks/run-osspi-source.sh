#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$here/git.sh"


if [ "${GITHUB_KEY+defined}" = defined ] && [ -n "$GITHUB_KEY" ]; then
  echo "Adding git key from GITHUB_KEY"
  source "$here/add-key.sh"
fi

echo "Running OSSPI"

interaction_type='Distributed - Calling Existing Classes'
if [ "${INTERACTION_TYPE+defined}" = defined ] && [ -n "$INTERACTION_TYPE" ]; then
  interaction_type="$INTERACTION_TYPE"
  printf "Using custom INTERACTION_TYPE: %s\n\n" "$interaction_type"
else
  printf "Using default INTERACTION_TYPE: %s\n\n" "$interaction_type"
fi

# Using artifactory to avoid rate limiting
npm config set registry http://build-artifactory.eng.vmware.com:80/artifactory/api/npm/npm

declare -a close_out_package_managers_flag
close_out_package_managers_flag=("-a" "golang" "-a" "rubygem" "-a" "maven" "-a" "npm" "-a" "gradle" "-a" "bower" "-a" "other")

echo "$USERNAME" "$API_KEY" > apiKeyFile

declare -a scanning_params_flag
if [ "${OSSPI_SCANNING_PARAMS+defined}" = defined ] && [ -n "$OSSPI_SCANNING_PARAMS" ]; then
  printf "%s" "$OSSPI_SCANNING_PARAMS" > "/scanning-params.yaml"
  scanning_params_flag=("--conf" "/scanning-params.yaml")
  printf "Using configured OSSPI_SCANNING_PARAMS:\n%s\n\n" "$OSSPI_SCANNING_PARAMS"
else
  scanning_params_flag=("--conf" "scanning-params.yaml")
fi

declare -a ignore_package_flag
if [ "${OSSPI_IGNORE_RULES+defined}" = defined ] && [ -n "$OSSPI_IGNORE_RULES" ]; then
  printf "%s" "$OSSPI_IGNORE_RULES" > "/ignore-rules.yaml"
  ignore_package_flag=("--ignore-package-file" "/ignore-rules.yaml")
  printf "Using configured OSSPI_IGNORE_RULES:\n%s\n\n" "$OSSPI_IGNORE_RULES"
fi

repo_name=
if ! git_repo_name "$REPO" 'repo_name'; then
  echo "Error getting repo name" >&2
  return 1
fi
echo "Repo name: $repo_name"

declare -a package_group_name_flag
package_group_name_flag=("-gn" "$repo_name")

if [ "${OSM_PACKAGE_GROUP_NAME+defined}" = defined ] && [ -n "$OSM_PACKAGE_GROUP_NAME" ]; then
  echo "Using OSM_PACKAGE_GROUP_NAME: $OSM_PACKAGE_GROUP_NAME"
  package_group_name_flag=("-gn" "$OSM_PACKAGE_GROUP_NAME")
else
  echo "Using repo name as OSM package group name: $repo_name"
fi

repo_commit=
if ! git_repo_commit "$REPO" 'repo_commit'; then
  echo "Error getting repo commit" >&2
  return 1
fi
echo "Repo commit (and package group version): $repo_commit"
osm_package_group_version="$repo_commit"

# Running this scan outside the $REPO because if running from within $REPO
# the is_repo_root function can't find the $REPO
if [ "${ENABLE_SINGLE_PACKAGE_SCAN:-false}" = true ]; then
  source "$here/repo-package.sh"
  build_repo_osm_manifest \
      "$REPO" \
      "Distributed - Calling Existing Classes" \
      "$REPO/repo_osm_results.json"
else
  echo "Disabled single package scanning"
fi

pushd "$REPO"
  echo "$USERNAME" "$API_KEY" > apiKeyFile

  if [ "${PREPARE+defined}" = defined ] && [ -n "$PREPARE" ]; then
    printf "Running Prepare Command:\n%s\n\n" "$PREPARE"
    bash -c "$PREPARE"
  fi

  set -x

  osspi scan bom \
    "${scanning_params_flag[@]}" \
    "${ignore_package_flag[@]}" \
    --format json \
    --output-dir "$REPO"_bom

  if [ "${ENABLE_SIGNATURE_SCAN+defined}" = defined ] && [ "$ENABLE_SIGNATURE_SCAN" = 'true' ]; then
    osspi scan signature \
      "${scanning_params_flag[@]}" \
      "${ignore_package_flag[@]}" \
      --format json \
      --output-dir "$REPO"_signature
  else
    echo "Disabled signature scanning"
  fi

  set +x

  declare -a merge_input_params

  # If nothing was found through bom scan, then bom results file is not created
  if [ -f "$REPO"_bom/osspi_bom_detect_result.json ]; then
    merge_input_params+=('--input' "$REPO"_bom/osspi_bom_detect_result.json)
  fi

  # If signature scan was not enabled, then signature results file is not created
  if [ -f "$REPO"_signature/osspi_signature_detect_result.json ]; then
    merge_input_params+=('--input' "$REPO"_signature/osspi_signature_detect_result.json)
  fi

  # If single package scan was not enabled, then single package scan results file is not created
  if [ -f repo_osm_results.json ]; then
    merge_input_params+=('--input' repo_osm_results.json)
  fi

  if [ ! "${merge_input_params+defined}" = defined ] || [ ${#merge_input_params[@]} -eq 0 ]; then
    echo "No scan result files, exiting..."
    exit 0
  fi

  set -x

  osspi merge \
    "${merge_input_params[@]}" \
    --output total_reports.manifest

  set +x

  str='[]'
  if [[ $(< total_reports.manifest) = "$str" ]]; then
    echo "Scan results are empty, exiting..."
    exit 0
  fi

  declare -a osstp_dry_run_flag
  if [ "${OSSTP_LOAD_DRY_RUN+defined}" = defined ] && [ "$OSSTP_LOAD_DRY_RUN" = 'true' ]; then
    osstp_dry_run_flag=('-n')
    echo "Dry run mode enabled for osstp-load"
  fi

  declare -a osstp_multiple_group_versions_flag
  if [ "${OSSTP_MULTIPLE_GROUP_VERSIONS+defined}" = defined ] && [ "$OSSTP_MULTIPLE_GROUP_VERSIONS" = 'true' ]; then
    osstp_multiple_group_versions_flag=('--multiple-group-versions')
    echo "Multiple group versions enabled for osstp-load"
  fi

  set -x

  osstp-load.py \
    "${osstp_dry_run_flag[@]}" \
    -S "$OSM_ENVIRONMENT" \
    -F \
    -A apiKeyFile \
    -I "$interaction_type" \
    -R "$PRODUCT"/"$(<${VERSION_FILE})" \
    --noinput \
    "${close_out_package_managers_flag[@]}" \
    "${package_group_name_flag[@]}" \
    -gv "$osm_package_group_version" \
    total_reports.manifest

  set +x
popd
