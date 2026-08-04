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

key_args=()
if [[ -f secrets.toml ]]; then
  key_args=(-k secrets.toml)
fi

nvfetcher "${key_args[@]}" -c nvfetcher.toml

last_byte=$(tail -c 1 _sources/generated.json)
if [[ -n "$last_byte" ]]; then
  printf '\n' >>_sources/generated.json
fi

list_files -g 'update.*' pkgs/by-name \
  | while IFS= read -r -d '' update_script; do
    if [[ ! -x "$update_script" ]]; then
      echo "Package update script is not executable: $update_script" >&2
      exit 1
    fi

    echo "Running $update_script"
    "$update_script"
  done

list_files -g package.nix pkgs/by-name \
  | while IFS= read -r -d '' package_file; do
    if rg --quiet '(vendor|cargo|npm|pnpm).*(Hash|Sha256)\s*=' "$package_file"; then
      package_name=$(basename "$(dirname "$package_file")")
      nix-update "$package_name" --flake --version=skip
    else
      status=$?
      if ((status > 1)); then
        exit "$status"
      fi
    fi
  done
