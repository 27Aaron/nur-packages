#!/usr/bin/env bash

# Single entry point for the complete local validation suite. CI runs this
# same script, so local and remote checks can never drift apart.
#
# --no-build skips the real `nix flake check` build pass and keeps the rest,
# for callers that have already built the affected packages.

set -o errexit
set -o nounset
set -o pipefail

usage() {
  echo "Usage: $0 [--no-build]" >&2
}

build_mode=true
case $# in
  0) ;;
  1)
    if [[ $1 != "--no-build" ]]; then
      usage
      exit 2
    fi
    build_mode=false
    ;;
  *)
    usage
    exit 2
    ;;
esac

repository_root=$(git rev-parse --show-toplevel)
cd "$repository_root"

readonly flake_ref="path:${repository_root}"

# A broken file symlink must be rejected by discovery, and the rejection must
# come from the fixture path rather than an unrelated evaluation failure.
check_eval_failures() {
  local error_log
  error_log=$(mktemp)

  if nix-instantiate --eval checks/eval/discover-broken.nix >/dev/null 2>"$error_log"; then
    echo "Broken file symlink was accepted by discovery" >&2
    rm -f "$error_log"
    return 1
  fi

  if ! grep --extended-regexp --quiet 'broken/(broken|missing)\.nix' "$error_log" \
    || ! grep --extended-regexp --quiet 'No such file or directory|does not exist' "$error_log"; then
    echo "Discovery failed for an unexpected reason:" >&2
    tail -n 120 "$error_log" >&2
    rm -f "$error_log"
    return 1
  fi

  rm -f "$error_log"
}

# Every package with a hashes.json must ship an update.* script that is
# executable on disk and in the Git index, so daily automation cannot
# silently skip a package whose updater was forgotten.
check_updaters() {
  local status=0
  local hashes_file
  local package_directory
  local package
  local update_script
  local git_mode

  shopt -s nullglob
  for hashes_file in pkgs/by-name/*/*/hashes.json; do
    package_directory=$(dirname "$hashes_file")
    package=$(basename "$package_directory")

    found_updater=false
    for update_script in "$package_directory"/update.*; do
      found_updater=true
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

    if [[ $found_updater == false ]]; then
      echo "Package '$package' has hashes.json but no update.* script" >&2
      status=1
    fi
  done
  shopt -u nullglob

  return "$status"
}

nix fmt -- --ci
nix flake check "$flake_ref" --no-build --all-systems --no-write-lock-file
nix run "$flake_ref#update-readme" -- --check

if [[ $build_mode == true ]]; then
  nix flake check "$flake_ref" --no-write-lock-file
fi

check_eval_failures
check_updaters

find scripts checks pkgs/by-name -type f -name '*.sh' -exec bash -n {} +
nixpkgs_path=$(
  nix eval --raw --impure \
    --expr '(builtins.getFlake ("path:" + toString ./.)).inputs.nixpkgs.outPath'
)
NIX_PATH="nixpkgs=$nixpkgs_path" nix-instantiate --eval -A buildOutputs ci.nix >/dev/null
NIX_PATH="nixpkgs=$nixpkgs_path" nix-instantiate --eval -A cacheOutputs ci.nix >/dev/null
NIX_PATH="nixpkgs=$nixpkgs_path" nix-instantiate --eval -A cachePaths ci.nix >/dev/null

git diff --check
git diff --cached --check
