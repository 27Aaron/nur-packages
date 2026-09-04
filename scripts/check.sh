#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

repository_root=$(git rev-parse --show-toplevel)
cd "$repository_root"

readonly flake_ref="path:${repository_root}"

nix fmt -- --ci
nix flake check "$flake_ref" --no-build --all-systems --no-write-lock-file
nix run "$flake_ref#update-readme" -- --check
nix flake check "$flake_ref" --no-write-lock-file

checks/check-eval-failures.sh

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
