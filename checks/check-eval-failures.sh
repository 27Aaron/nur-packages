#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

error_log=$(mktemp)
trap 'rm -f "$error_log"' EXIT

if nix-instantiate --eval checks/eval/discover-broken.nix >/dev/null 2>"$error_log"; then
  echo "Broken file symlink was accepted by discovery" >&2
  exit 1
fi

if ! grep --extended-regexp --quiet 'broken/(broken|missing)\.nix' "$error_log" \
  || ! grep --extended-regexp --quiet 'No such file or directory|does not exist' "$error_log"; then
  echo "Discovery failed for an unexpected reason:" >&2
  tail -n 120 "$error_log" >&2
  exit 1
fi
