# shellcheck shell=bash

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$here/debug.sh"

# generate_osm_snippet
# Print out a OSM manifest for a package with a repo
# $1 - package name
# $2 - package version
# $3 - package interaction type
# $4 - OSM snippet out var
# $5 - tarball filepath
function generate_osm_snippet {
  local osm_snippet_out_var="$4"

  local tarball="$5"

  local osm_manifest_snippet
  osm_manifest_snippet="$(
    cat <<END
other:$1:$2:
  name: '$1'
  version: '$2'
  repository: 'Other'
  interactions: ['$3']
  other-distribution: '$tarball'
END
  )"

  if is_debug_mode; then printf "OSM snippet:\n%s\n" "$osm_manifest_snippet" >&2; fi

  printf -v "$osm_snippet_out_var" "$osm_manifest_snippet"
}

# generate_osm_snippet_json
# Print out a OSM json snippet for a package with a repo
# $1 - package name
# $2 - package version
# $3 - package interaction type
# $4 - OSM snippet out var
# $5 - tarball filepath
function generate_osm_snippet_json {
  local osm_snippet_out_var="$4"

  local tarball="$5"

  local osm_manifest_snippet
  osm_manifest_snippet="$(
    cat <<END
{
"packages" : [
  {
   "_unique_id": "$1-$2",
   "name": "$1",
   "version": "$2",
   "repository": "Other",
   "interactions": ["$3"],
   "other-distribution": "$tarball"
  }
 ],
 "server": {}
}
END
  )"

  if is_debug_mode; then printf "OSM json snippet:\n%s\n" "$osm_manifest_snippet" >&2; fi

  printf -v "$osm_snippet_out_var" "$osm_manifest_snippet"
}

# print_manifest
# $1 - full manifest string
# $2 - manifest output path
function print_manifest {
  echo
  echo "#####################"
  echo "# Full OSM Manifest #"
  echo "#####################"
  echo "$1"

  # Save to file
  echo "$1" > "$2"
  echo

  echo "OSM manifest saved to: $2"
}

