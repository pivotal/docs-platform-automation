# shellcheck shell=bash

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$here/debug.sh"
source "$here/files.sh"
source "$here/git.sh"
source "$here/osm.sh"
source "$here/strings.sh"

# build_blobs_osm_manifest
# Generate a OSM manifest from BOSH blobs. This will create an OSM package for each blob, and also upload the blob source code to OSM.
# $1 - blobs.yml (usually <bosh-release/config/blobs.yml>)
# $2 - blob_sources.yml
# $3 - output path of the generated manifest file
function build_blobs_osm_manifest {
  if [ "$#" -ne 3 ]; then
    echo "Error: incorrect parameters" >&2
    print_blobs_usage
    return 1
  fi

  if [ ! -f "$1" ]; then
    echo "Error: blobs yml does not exist: $1" >&2
    return 1
  fi

  if [ ! -f "$2" ]; then
    echo "Error: blob_sources.yml does not exist: $2" >&2
    return 1
  fi

  BLOB_SOURCES="$2"

  if ! read_blobs "$1" "$3"; then
    echo "Failed to build OSM manifest" >&2
    echo "Try running with DEBUG=on" >&2
    return 1
  fi
}

function print_blobs_usage {
  echo "Usage: [DEBUG=on] build_blobs_osm_manifest <bosh blobs yaml path> <blob sources config yaml path> <manifest output path>"
}

# read_blobs
# Go through each blob and finds the URL or git repo/ref to download blob sources from.
# $1 - blobs.yml
# $2 - OSM manifest output path
function read_blobs {
  local blob_name
  declare -a osm_snippets

  while IFS=$' ' read -r _ blob_name; do
    echo "======================================="
    echo "Finding name pattern and url for blob:"
    echo "$blob_name"
    echo "======================================="

    # Find the blob_sources.yml entry that matches this blob
    local name_pattern
    name_pattern="$(find_name_pattern "$blob_name")"
    if [[ -z "$name_pattern" ]]; then
      echo "Cannot find matching name_pattern in blob_sources.yml, exiting..." >&2
      return 1
    fi
    echo "Name pattern found that matches blob: $name_pattern"

    # See if blob_sources.yml is configured to skip this blob
    if determine_skip "$name_pattern"; then echo "Skipping..."; echo; continue; fi

    # Use the version template to determine the OSM package version to submit
    local osm_package_name
    local osm_package_version
    local osm_package_interaction_type

    if ! get_osm_values "$name_pattern" "$blob_name" 'osm_package_name' 'osm_package_version' 'osm_package_interaction_type'; then
      echo "Error getting OSM values from blob_sources.yml"
      return 1
    fi

    if [ -z "$osm_package_name" ]; then
      echo "Warning: Defaulting to using blob name as package name"
      osm_package_name="$blob_name"
    fi
    echo "OSM package name: $osm_package_name"

    if [ -z "$osm_package_version" ]; then
      echo "Warning: Defaulting to using blob SHA as package version"
      local blob_sha
      if ! get_blob_sha "$1" "$blob_name" 'blob_sha'; then
        echo "Error: could not get blob SHA" >&2
        return 1
      fi
      osm_package_version="$blob_sha"
    fi
    echo "OSM package version: $osm_package_version"

    if [ -z "$osm_package_interaction_type" ]; then
      echo "Warning: Defaulting to using interaction type: 'Distributed - Calling Existing Classes'"
      osm_package_interaction_type='Distributed - Calling Existing Classes'
    fi
    echo "Interaction type: $osm_package_interaction_type"


    # Check to see if this is a URL type blob source. If so, then determine the final URL.
    local url_template=
    local osm_snippet=

    get_blob_source_value "$name_pattern" "url" 'url_template'
    if [[ -n "$url_template" ]]; then
      if ! handle_blob_url "$name_pattern" "$blob_name" "$osm_package_name" "$osm_package_version" "$osm_package_interaction_type" "$url_template" 'osm_snippet'; then
        echo "Error handling URL blob source" >&2
        return 1
      fi
    else
      if ! handle_blob_repo "$name_pattern" "$blob_name" "$osm_package_name" "$osm_package_version" "$osm_package_interaction_type" 'osm_snippet'; then
        echo "Error handling git blob source" >&2
        return 1
      fi
    fi

    osm_snippets+=( "$osm_snippet" )

    echo

  done < <(yq e '. | keys' "$1")

  local full_osm_manifest
  # neat trick with array expanson needed in case osm_snippets is empty
  printf -v full_osm_manifest "%s\n" "${osm_snippets[@]+"${osm_snippets[@]}"}"

  print_manifest "$full_osm_manifest" "$2"
}

# determine_skip <name pattern>
# Get the skip configuration for a blob
function determine_skip {
  local skip
  get_blob_source_value "$name_pattern" 'skip' 'skip'
  if [[ -z "$skip" || "$skip" != "true" ]]; then
    return 1
  fi
}

# get_osm_values
# Get the OSM values from blob_sources.yml
# $1 - name pattern for the blob source
# $2 - blob name
# $3 - out var for OSM package name
# $4 - out var for OSM package version
# $5 - out var for OSM package interaction type
function get_osm_values {
  local package_name
  if ! get_or_error_osm_value "$1" "$2" 'name' 'package_name'; then
    echo "Warning: Cannot get OSM package name from blob_sources.yml"
    package_name=
  fi
  printf -v "$3" "$package_name"

  # Use the version template to determine the OSM package version to submit
  local package_version_template
  local package_version
  if ! get_or_error_osm_value "$1" "$2" 'version' 'package_version_template'; then
    echo "Warning: Cannot get OSM package version template string from blob_sources.yml" >&2
    package_version=
  else
    echo "Package version template: $package_version_template"
    if ! regex_sub "$1" "$2" "$package_version_template" 'package_version'; then
      echo "Error performing regex replacement on OSM package version" >&2
      return 3
    fi
  fi
  printf -v "$4" "$package_version"

  local interaction_type
  if ! get_or_error_osm_value "$1" "$2" 'interaction_type' 'interaction_type'; then
    echo "Warning: Cannot get OSM package interaction type from blob_sources.yml" >&2
    interaction_type=
  fi
  printf -v "$5" "$interaction_type"
}

# get_or_error_osm_value
# Get the version string for what OSM interaction type should be for a blob
# $1 - name pattern
# $2 - blob name
# $3 - key name
# $4 - value out var
function get_or_error_osm_value {
  local name_pattern="$1"
  local blob_name="$2"
  local key_name="$3"
  local value_out="$4"

  if ! get_bosh_source_osm_value "$name_pattern" "$key_name" "$value_out"; then
    echo "Warning: Cannot find osm.$key_name in blob_sources.yml" >&2
    return 1
  elif [[ -z ${!value_out} ]]; then
    echo "Warning: osm.$key_name in blob_sources.yml is blank" >&2
    return 2
  fi
}

# find_name_pattern <blob name>
# Try to find the name pattern in blob_sources.yml that matches the blob name
function find_name_pattern {
  local blob_name="$1"

  # iterate through each entry in blob_sources
  while IFS=$'\t' read -r name_pattern; do
    [[ $blob_name =~ $name_pattern ]] # $name_pattern must be unquoted

    # If there's no match, then continue
    if [[ -z ${BASH_REMATCH+x} ]]; then
      continue
    fi

    echo "$name_pattern"
  done < <(yq e '.blobs[] | [.name_pattern] | @tsv' "$BLOB_SOURCES")
}

# get blob_sha
# For a particular blobs.yml entry, get the blob SHA
# $1 - blobs.yml path
# $2 - Name of the blob in blobs.yml
# $3 - Out vaiable for the value
function get_blob_sha {
  local search=".\"$2\" | .sha"
  local value

  declare -a yq_command
  yq_command=("yq" "e" "$search" "$1")

  if is_debug_mode; then echo "yq command: ${yq_command[*]}" >&2; fi
  
  value=$("${yq_command[@]}")
  if [ $? -ne 0 ]; then
    echo "Warning yq failed, cannot find blob SHA for blob: $2" >&2
    return 1
  fi

  if [ "$value" = 'null' ]; then
    echo "Warning: cannot find blob sha for blob: $2" >&2
    value=''
    return 1
  fi

  if is_debug_mode; then echo "yq got sha: $value" >&2; fi

  value=${value#'sha256:'}

  printf -v "$3" "$value"
}



# get_blob_source_value
# For a particular blob_sources.yml entry, look for the specified key and print the value
# $1 - Name pattern of the relevant entry in blob_sources.yml
# $2 - Key name for the desired value
# $3 - Out variable for the value
function get_blob_source_value {
  local name_pattern="$1"
  local key_name="$2"
  local value_out_var="$3"

  local search=".blobs[] | select(has(\"$key_name\")) | select(.name_pattern == \"$name_pattern\") | .$key_name"
  local value
  value=$(yq e "$search" "$BLOB_SOURCES")

  if [ "$value" = 'null' ]; then
    value=''
    return 1
  fi

  if is_debug_mode; then echo "Key '$key_name' has value '$value'" >&2; fi

  printf -v "$value_out_var" "$value"
}

# get_bosh_source_osm_value <name pattern> <osm key name> <value out var>
# For a particular blob_sources entry, look inside its `osm` map, and look for a particular key and
# print the value.
function get_bosh_source_osm_value {
  local name_pattern="$1"
  local key_name="$2"
  local value_out_var="$3"

  local search=".blobs[] | select(has(\"osm\")) | select(.name_pattern == \"$name_pattern\") | .osm.$key_name"
  local value
  value=$(yq e "$search" "$BLOB_SOURCES")

  if [ "$value" = 'null' ]; then
    value=''
    return 1
  fi

  if is_debug_mode; then echo "Key 'osm.$key_name' has value '$value'" >&2; fi

  printf -v "$value_out_var" "$value"
}

# handle_blob_url
# Build OSM manifest snippet for a blob with with URL source
# $1 - Name pattern for the relevant blob source entry
# $2 - Blob name
# $3 - OSM package name
# $4 - OSM package version
# $5 - OSM package interaction type
# $6 - URL template string
# $7 - Out var for the OSM manifest snippet
# <OSM snippet out var>
function handle_blob_url {
  local url
  if ! regex_sub "$1" "$2" "$6" 'url'; then
    echo "Error while regex replacement on URL" >&2
    return 1
  fi

  echo "URL: $url"

  local download_dir
  if ! temp_download_dir "$2" download_dir; then
    echo "Error: could not create temp dir" >&2
    return 5
  fi

  # Download the file in the URL
  local downloaded_file_path
  if ! download_file "$url" "$download_dir" 'downloaded_file_path'; then
    echo "Error: could not download file" >&2
    return 10
  fi

  generate_osm_snippet "$3" "$4" "$5" "$7" "$downloaded_file_path"
}

# get_git_templates <name pattern> <git repo out var> <git ref out var> <shallow clone out var>
# Read the git configuration of a specific blob pattern
# $1 - Name pattern for the relevant blob sources entry
# $2 - Out var for git repo
# $3 - Out var for git ref
# $4 - Out var for shallow clone
function get_git_templates {
  if ! get_blob_source_value "$1" 'repo' "$2"; then
    echo "Error getting git repo" >&2
    return 1
  fi

  if ! get_blob_source_value "$1" 'ref' "$3"; then
    echo "Error getting git ref" >&2
    return 1
  fi

  if ! get_blob_source_value "$1" 'shallow_clone' "$4"; then
    echo "Warning, could not get configuration for shallow_clone, defaulting to true" >&2
    printf -v "$4" 'true'
  fi
}

# handle_blob_repo <name pattern> <blob name> OSM package name <package version> <package interaction type> <OSM snippet out var>
# Build a OSM manifeset snippet for a blob with repo source
# $1 - Name pattern for the relevant blob sources entry
# $2 - Blob name
# $3 - OSM package name
# $4 - OSM package version
# $5 - OSM package interaction type
# $6 - Out var for OSM snippet
function handle_blob_repo {
  local git_repo_template
  local git_ref_template
  local git_repo
  local git_ref
  local shallow_clone

  if ! get_git_templates "$1" git_repo_template git_ref_template shallow_clone; then
    echo "Error getting blob source git info" >&2
    return 1
  fi

  if [ -z "$git_repo_template" ] || [ -z "$git_ref_template" ]; then
    echo "Error: git repo template or git ref template is blank" >&2
    return 2
  fi

  if ! regex_sub "$1"  "$2" "$git_repo_template" 'git_repo'; then
    echo "Error while performing regex replacement on git repo" >&2
    return 3
  fi
  echo "Git repo: $git_repo"

  if ! regex_sub "$1"  "$2" "$git_ref_template" 'git_ref'; then
    echo "Error while performing regex replacement on git ref" >&2
    return 3
  fi

  if [ -z "$git_ref" ]; then
    echo "Error: git ref is blank" >&2
    return 4
  fi
  echo "Git ref: $git_ref"

  local download_dir
  if ! temp_download_dir "$2" download_dir; then
    echo "Error: could not create temp dir" >&2
    return 5
  fi

  local repo_dst_dir
  if ! git_clone "$git_ref" "$git_repo" "$shallow_clone" "$download_dir" 'repo_dst_dir'; then
    echo "Error: clone failed" >&2
    return 6
  fi

  local tarball_filepath
  if ! create_tarball "$repo_dst_dir" "$download_dir" 'tarball_filepath'; then
    echo "Error creating tarball" >&2
    return 7
  fi

  generate_osm_snippet "$3" "$4" "$5" "$6" "$tarball_filepath"
}
