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

# Failure isolation: one failing updater must not block updates for the
# remaining packages. Failures are collected, reported at the end, and still
# turn the exit status non-zero; optional NUR_UPDATE_FAILURES_FILE receives
# the failed package names for callers that publish partial updates.
failures_file=$(mktemp)
cleanup() {
  rm -f "$failures_file"
}
trap cleanup EXIT

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
  if "$update_script"; then
    :
  else
    package=$(basename "$(dirname "$update_script")")
    echo "Updater for '$package' failed: $update_script" >&2
    if [[ -n ${GITHUB_ACTIONS:-} ]]; then
      echo "::error title=Updater failed::$package" >&2
    fi
    printf '%s\n' "$package" >>"$failures_file"
  fi
done

scripts/update-readme.sh

if [[ -s "$failures_file" ]]; then
  echo "The following updaters failed and were left unchanged:" >&2
  sed 's/^/  - /' "$failures_file" >&2
  if [[ -n ${NUR_UPDATE_FAILURES_FILE:-} ]]; then
    cp "$failures_file" "$NUR_UPDATE_FAILURES_FILE"
  fi
  exit 1
fi
