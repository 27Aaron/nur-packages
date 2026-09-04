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

list_files -g 'update.*' pkgs/by-name \
  | while IFS= read -r -d '' update_script; do
    if [[ ! -x "$update_script" ]]; then
      echo "Package update script is not executable: $update_script" >&2
      exit 1
    fi

    echo "Running $update_script"
    "$update_script"
  done
