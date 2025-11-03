#!/bin/bash

set -e
set -u

# Fetch environment variables
HOST="${RMT_HOST}"
USERNAME="${RMT_USERNAME}"
PASSWORD="${RMT_PASSWORD}"
EMAIL="${RMT_EMAIL}"
SFTP_HOST="${SFTP_HOST}"
SFTP_USERNAME="${SFTP_USERNAME}"
SFTP_PASSWORD="${SFTP_PASSWORD}"

# Store current directory
PWD_DIR=$(pwd)
OUTPUT_DIR=rmt-artifacts
INPUT_DIR=rmt-assets

# Helper function to log and execute a command
run_cmd() {
  echo "Executing: $*"
  eval "$@"
}

copy_rmt() {
  OS_NAME=$(uname | tr '[:upper:]' '[:lower:]')
  ARCH_NAME=$(uname -m)

  case "$ARCH_NAME" in
    x86_64) ARCH_NAME="amd64" ;;
    aarch64) ARCH_NAME="arm64" ;;
  esac

  echo "copying RMT with os $OS_NAME and architecture $ARCH_NAME"
  file=$(ls $INPUT_DIR | grep $OS_NAME | grep $ARCH_NAME)
  case "$file" in
  *.zip)
    unzip $INPUT_DIR/$file -d ${OUTPUT_DIR} ;;
  *.tar.gz)
    tar -xzf $INPUT_DIR/$file -C ${OUTPUT_DIR} ;;
  esac
  echo "Files copied to ${OUTPUT_DIR}"
  ${OUTPUT_DIR}/rmt --help
}

# Create rmt.yml function
create_rmt_file() {
  echo "$PWD_DIR"
  echo "Creating rmt.yml configuration file..."
  cat <<EOF > rmt.yml
verbose: true
rmt:
  host: "${HOST}"
  username: "${USERNAME}"
  password: "${PASSWORD}"
  email: "${EMAIL}"
  timeout_seconds: 90
sftp:
  host: "${SFTP_HOST}"
  username: "${SFTP_USERNAME}"
  password: "${SFTP_PASSWORD}"
EOF

  cp rmt.yml "${OUTPUT_DIR}"/
}

# Main execution
main() {
  copy_rmt
  create_rmt_file
}

main
