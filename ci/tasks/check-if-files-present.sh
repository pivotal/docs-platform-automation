#!/bin/bash
declare -a files=($(cat release.yml | yq -r '.files[].file'))

for file in "${files[@]}" ; do
    if [[ ! -f $file ]]; then
        echo "$file does not exist to upload..."
        exit 1
    fi
done
