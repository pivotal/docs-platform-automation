docker run -it --rm -v $PWD:/workspace -w /workspace platform-automation-image \
om --env ${ENV_FILE} staged-config --product-name ${SLUG} --include-placeholders