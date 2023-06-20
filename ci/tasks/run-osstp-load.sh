#!/usr/bin/env bash
set -euox pipefail

osspi merge --input docker_scan/osspi_docker_detect_result.json \
  --input repo2_bom/osspi_bom_detect_result.json \
  --output platform_automation_osspi_scan_results.manifest

declare -a osstp_dry_run_flag
if [ "${OSSTP_LOAD_DRY_RUN+defined}" = defined ] && [ "$OSSTP_LOAD_DRY_RUN" = 'true' ]; then
  osstp_dry_run_flag=('-n')
  echo "Dry run mode enabled for osstp-load"
fi

declare -a baseos_append_flag
if [ "${APPEND+defined}" = defined ] && [ "$APPEND" = 'true' ]; then
  baseos_append_flag=('--baseos-append')
  echo "Using --baseos-append flag"
fi

echo "$USERNAME" "$API_KEY" > apiKeyFile

osstp-load.py \
  "${osstp_dry_run_flag[@]}" \
  -S "$OSM_ENVIRONMENT" \
  -F \
  -R "$PRODUCT"/"$VERSION" \
  -A apiKeyFile \
  "${baseos_append_flag[@]}" \
  --noinput \
  platform_automation_osspi_scan_results.manifest

echo "15 minute warning"
sleep 15m
echo 'Goodbye!'
exit 0