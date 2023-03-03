# shellcheck shell=bash

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$here/debug.sh"
source "$here/files.sh"
source "$here/git.sh"
source "$here/osm.sh"

# build_repo_osm_manifest
# Generate an OSM manifest using a git repo as the root
# $1 - repo dir
# $2 - interaction type of the OSM package
# $3 - OSM manifest output path
function build_repo_osm_manifest {
  if [ "$#" -ne 3 ]; then
    echo "Error: incorrect parameters" >&2
    print_repo_package_usage
    return 1
  fi

  if ! is_repo_root "$1"; then
    echo "Error: Directory is not a repo root: $1" >&2
    return 1
  fi

  local repo_name
  if ! git_repo_name "$1" 'repo_name'; then
    echo "Error getting repo name" >&2
    return 1
  fi
  echo "Repo name: $repo_name"

  local repo_commit
  if ! git_repo_commit "$1" 'repo_commit'; then
    echo "Error getting repo commit" >&2
    return 1
  fi
  echo "Repo commit: $repo_commit"

  local download_dir
  if ! temp_download_dir "$repo_name" download_dir; then
    echo "Error: could not create temp dir" >&2
    return 5
  fi

  local tarball_path
  if ! create_tarball "$1" "$download_dir" 'tarball_path'; then
    echo "Error: could not create tarball from repo path"
    return 1
  fi

  local osm_snippet
  if "$ENABLE_SINGLE_PACKAGE_SCAN"; then
    if ! generate_osm_snippet_json "$repo_name" "$repo_commit" "$2" 'osm_snippet' "$tarball_path"; then
      echo "Error generating OSM snippet" >&2
      return 1
    fi
  else
    if ! generate_osm_snippet "$repo_name" "$repo_commit" "$2" 'osm_snippet' "$tarball_path"; then
      echo "Error generating OSM snippet" >&2
      return 1
    fi
  fi

  print_manifest "$osm_snippet" "$3"
}

function print_repo_package_usage {
  echo "Usage: [DEBUG=on] build_repo_osm_manifest <repo> <OSM interaction type> <manifest output path>"
}
