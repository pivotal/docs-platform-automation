#!/usr/bin/env bash
# code_snippet make-git-commit-script start bash

cat /var/version && echo ""
set -eu

git clone repository repository-commit

FILE_DESTINATION_PATH="repository-commit/${FILE_DESTINATION_PATH}"
destination_directory=$(dirname "${FILE_DESTINATION_PATH}")

if [ ! -d "${destination_directory}" ]; then
  echo "Directory ${destination_directory} does not exist in repository, creating it..."
  mkdir -p "${destination_directory}"
fi

cp file-source/"${FILE_SOURCE_PATH}" \
  "${FILE_DESTINATION_PATH}"
cd repository-commit
git config user.name "${GIT_AUTHOR_NAME}"
git config user.email "${GIT_AUTHOR_EMAIL}"
if [[ -n $(git status --porcelain) ]]; then
  git add -A
  git commit -m "${COMMIT_MESSAGE}" --allow-empty
fi
# code_snippet make-git-commit-script end
