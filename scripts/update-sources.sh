set -o errexit
set -o nounset
set -o pipefail

list_files() {
  local status

  if rg --files --null --sort path "$@"; then
    return 0
  else
    status=$?
  fi

  if ((status == 1)); then
    return 0
  fi

  return "$status"
}

# Optional arguments restrict the run to named packages; without arguments
# every discovered updater runs. Validate the request up front so a typo
# cannot silently update nothing.
if (( $# > 0 )); then
  shopt -s nullglob
  for package in "$@"; do
    package_scripts=(pkgs/by-name/*/"$package"/update.*)
    if (( ${#package_scripts[@]} == 0 )); then
      echo "No package named '$package' with an update.* script" >&2
      exit 1
    fi
    for script in "${package_scripts[@]}"; do
      if [[ ! -x $script ]]; then
        echo "Package update script is not executable: $script" >&2
        exit 1
      fi
    done
  done
  shopt -u nullglob
fi

update_selection() {
  if (( $# == 0 )); then
    list_files -g 'update.*' pkgs/by-name
    return
  fi

  for package in "$@"; do
    list_files -g 'update.*' pkgs/by-name/*/"$package"
  done
}

update_selection "$@" | while IFS= read -r -d '' update_script; do
  if [[ ! -x "$update_script" ]]; then
    echo "Package update script is not executable: $update_script" >&2
    exit 1
  fi

  echo "Running $update_script"
  "$update_script"
done

scripts/update-readme.sh
