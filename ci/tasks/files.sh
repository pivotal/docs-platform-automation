# shellcheck shell=bash

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$here/debug.sh"

# temp_download_dir
# Generate a temporary dowload directory based a string
# $1 - Name to base temp dir on
# $2 - Out var for directory path for the temp dir
function temp_download_dir {
  local base_name="$1"

  local dir_name
  dir_name="${base_name//[^a-zA-Z0-9]/_}"

  local tmp_dir
  tmp_dir=$(mktemp -d)/$dir_name
  mkdir -p "$tmp_dir"

  if is_debug_mode; then echo "Temp dir created: '$tmp_dir'" >&2; fi

  printf -v "$2" "$tmp_dir"
}

# download_file
# Download file into specified directory
# $1 - The URL to download
# $2 - The parent directory of the output the downloaded file
# $3 - Out var for the filepath of the resulting file
function download_file {
  local curl_command=("curl" "--location" "--fail" "--no-progress-meter" "--remote-name" "--remote-header-name" "--write-out" "filename_effective: %{filename_effective}\n" "$url")

  echo "Curl command: ${curl_command[*]}"

  local curl_log_file
  curl_log_file=$(mktemp /tmp/curl_log.XXXXXX.txt)
  echo "Curl logs will be saved to: $curl_log_file"

  cd "$2" || return 1
  if is_debug_mode; then
    if ! "${curl_command[@]}" 2>&1 | tee "$curl_log_file"; then
      echo "Error: Curl failed, see logs: $curl_log_file" >&2
      cd - || return 2
      return 3
    fi
  else
    if ! "${curl_command[@]}" &> "$curl_log_file"; then
      echo "Error: Curl failed, see logs: $curl_log_file" >&2
      cd - || return 2
      return 3
    fi
  fi
  cd - || return 1

  local downloaded_file
  IFS=": "
  while read -r name value; do
    [ "$name" = 'filename_effective' ] && downloaded_file="$2/$value"
  done < "$curl_log_file"
  unset IFS

  echo "File downloaded: $downloaded_file"
  printf -v "$3" "$downloaded_file"
}

# create_tarball
# Create a download.tar.gz tarball from a git repo directory
# $1 - Directory to tar up
# $2 - The parent directory of the output download.tar.gz
# $3 - Out var for the filepath of the resulting download.tar.gz
function create_tarball {
  local tarball
  tarball="$2/download.tar.gz"
  if is_debug_mode; then
    if ! tar czv --exclude='.git' -f "$tarball" -C "$1" .; then
      "Error: tar command failed" >&2
      return 1
    fi
  else
    if ! tar cz --exclude='.git' -f "$tarball" -C "$1" .; then
      "Error: tar command failed" >&2
      return 1
    fi
  fi
  echo "Tarball created: $tarball"
  printf -v "$3" "$tarball"
}

