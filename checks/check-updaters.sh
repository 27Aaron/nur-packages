#!/usr/bin/env bash

# Every package with a hashes.json must ship an executable update.* script,
# both on disk and in the Git index, so daily automation cannot silently skip
# a package whose updater was forgotten or lost its executable bit.

set -o errexit
set -o nounset
set -o pipefail

repository_root=$(git rev-parse --show-toplevel)
cd "$repository_root"

status=0
shopt -s nullglob
for hashes_file in pkgs/by-name/*/*/hashes.json; do
  package_directory=$(dirname "$hashes_file")
  package=$(basename "$package_directory")
  update_scripts=("$package_directory"/update.*)

  if (( ${#update_scripts[@]} == 0 )); then
    echo "Package '$package' has hashes.json but no update.* script" >&2
    status=1
    continue
  fi

  for update_script in "${update_scripts[@]}"; do
    if [[ ! -x $update_script ]]; then
      echo "Package update script is not executable on disk: $update_script" >&2
      status=1
    fi
    git_mode=$(git ls-files -s -- "$update_script" | awk '{print $1}')
    if [[ $git_mode != 100755 ]]; then
      echo "Package update script is not executable in Git: $update_script" >&2
      status=1
    fi
  done
done
shopt -u nullglob

if (( status != 0 )); then
  exit 1
fi
