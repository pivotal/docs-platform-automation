# shellcheck shell=bash

# regex_sub
# Finds all the regex match that name pattern has when using blob name.
# Outputs in the URL after filling in template with all the matches.
# $1 - name pattern for the blob source entry
# $2 - blob name
# $3 - template string
# $4 - out var for final URL
function regex_sub {
  [[ $2 =~ $1 ]] # $name_pattern must be unquoted

  if [[ -z ${BASH_REMATCH+x} ]]; then
    return 1
  fi

  # replace all the placeholders with found regex captured group values
  local final_url
  final_url=$(iterate_replace "${BASH_REMATCH[@]}" "$3")
  printf -v "$4" "$final_url"
}

# iterate_replace <matches array variable name> <template>
# Replace the placeholders in the template with the elements of the matches array of capture groups.
# Replace value named "match1" with the first regex capture group, "match2" with
# the second regex capture group, and so on.
function iterate_replace {
  local matches=("$@")
  ((last_idx = ${#matches[@]} - 1))
  local template=${matches[last_idx]}
  unset 'matches[last_idx]'

  local length=${#matches[@]}

  local final_string="$template"

  # For each match, replace a placeholder in the template
  for ((j = 1; j < length; j++)); do
    local old_text="<<match$j>>"
    local new_text=${matches[$j]}

    final_string="$(replace "$old_text" "$new_text" "$final_string")"
  done

  echo "$final_string"
}

# replace <old text> <new text> <template>
# Replace specific place holder from the template
function replace {
  local old_text="$1"
  local new_text="$2"
  local template="$3"

  echo "$template" | sed "s/$old_text/$new_text/g"
}
