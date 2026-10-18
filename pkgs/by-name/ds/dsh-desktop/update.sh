#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(git -C "$script_directory" rev-parse --show-toplevel)
# shellcheck source=../../../../scripts/update-lib.sh
source "$repository_root/scripts/update-lib.sh"

readonly hashes_file="$script_directory/hashes.json"
readonly package_file="pkgs/by-name/ds/dsh-desktop/package.nix"
readonly repo_url="https://github.com/deepseek-ai/deepseek-harness"

version_sort_key() {
  # sort -V orders 1.0 before 1.0-rc.1. Insert a trailing release marker so a
  # final release sorts after its pre-releases, then compare those keys.
  local version=$1
  if [[ $version == *-* ]]; then
    printf '%s\n' "$version"
  else
    printf '%s-~\n' "$version"
  fi
}

version_greater() {
  local left=$1
  local right=$2
  local winner
  winner=$(
    printf '%s\n' "$(version_sort_key "$left")" "$(version_sort_key "$right")" | sort -V | tail -n 1
  )
  [[ $winner == "$(version_sort_key "$left")" && $left != "$right" ]]
}

resolve_latest() {
  local tags best_tag rev
  tags=$(mktemp)
  git ls-remote --tags "$repo_url" 'refs/tags/dsh-v*' >"$tags"
  best_tag=$(
    grep -v '\^{}$' "$tags" |
      awk '{ print substr($2, 11) }' |
      while IFS= read -r tag; do
        printf '%s %s\n' "$(version_sort_key "${tag#dsh-v}")" "$tag"
      done |
      sort -V |
      awk 'END { print $2 }'
  )
  if [[ -z $best_tag ]]; then
    rm -f "$tags"
    echo "No dsh-v* tags found" >&2
    return 1
  fi
  rev=$(awk -v tag="refs/tags/${best_tag}^{}" '$2 == tag { print $1 }' "$tags")
  if [[ -z $rev ]]; then
    rev=$(awk -v tag="refs/tags/${best_tag}" '$2 == tag { print $1 }' "$tags")
  fi
  rm -f "$tags"
  if [[ -z $rev ]]; then
    echo "Could not resolve $best_tag" >&2
    return 1
  fi
  printf '%s %s\n' "${best_tag#dsh-v}" "$rev"
}

prefetch_pnpm_deps_hash() {
  local version=$1
  local rev=$2
  local source_hash=$3
  local pnpm_version=$4
  local pnpm_hash=$5
  local log
  log=$(mktemp)
  if nix build --no-link --no-write-lock-file --impure --expr "
    let
      repository = builtins.getFlake (\"path:\" + $(jq --null-input --arg root "$repository_root" '$root'));
      pkgs = repository.inputs.nixpkgs.legacyPackages.\${builtins.currentSystem};
      src = pkgs.fetchFromGitHub {
        owner = \"deepseek-ai\";
        repo = \"deepseek-harness\";
        rev = $(jq --null-input --arg rev "$rev" '$rev');
        hash = $(jq --null-input --arg hash "$source_hash" '$hash');
      };
      pnpm = pkgs.pnpm_11.override {
        version = $(jq --null-input --arg version "$pnpm_version" '$version');
        hash = $(jq --null-input --arg hash "$pnpm_hash" '$hash');
      };
    in
    pkgs.fetchPnpmDeps {
      pname = \"dsh-desktop\";
      version = $(jq --null-input --arg version "$version" '$version');
      inherit src pnpm;
      fetcherVersion = 4;
      hash = pkgs.lib.fakeHash;
    }
  " >"$log" 2>&1; then
    rm -f "$log"
    echo "pnpm dependency fetch unexpectedly succeeded with a dummy hash" >&2
    return 1
  fi
  local got
  got=$(sed -n 's/.*got:[[:space:]]*\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' "$log" | tail -n 1)
  if [[ -z $got ]]; then
    cat "$log" >&2
    rm -f "$log"
    echo "Could not read the pnpm dependency hash" >&2
    return 1
  fi
  rm -f "$log"
  printf '%s\n' "$got"
}

entry=$(resolve_latest)
latest_version=${entry%% *}
rev=${entry#* }
current_version=$(jq --exit-status --raw-output '.version | strings | select(length > 0)' "$hashes_file")

if [[ $current_version == "$latest_version" ]]; then
  echo "dsh-desktop is already up to date ($current_version)"
  exit 0
fi

if ! version_greater "$latest_version" "$current_version"; then
  echo "Refusing to downgrade dsh-desktop from $current_version to $latest_version" >&2
  exit 1
fi

echo "Updating dsh-desktop from $current_version to $latest_version ($rev)"
source_hash=$(prefetch_hash "https://github.com/deepseek-ai/deepseek-harness/archive/${rev}.tar.gz" unpack)
pnpm_version=$(
  curl --fail --silent --show-error --location \
    "https://raw.githubusercontent.com/deepseek-ai/deepseek-harness/${rev}/package.json" |
    jq --exit-status --raw-output '.packageManager | capture("^pnpm@(?<version>.+)$").version'
)
current_pnpm_version=$(jq --exit-status --raw-output '.pnpmVersion' "$hashes_file")
if [[ $pnpm_version == "$current_pnpm_version" ]]; then
  pnpm_hash=$(jq --exit-status --raw-output '.pnpmHash' "$hashes_file")
else
  echo "Upstream pnpm changed from $current_pnpm_version to $pnpm_version"
  pnpm_hash=$(prefetch_hash "https://registry.npmjs.org/pnpm/-/pnpm-${pnpm_version}.tgz")
fi

echo "Fetching the pnpm dependency hash"
pnpm_deps_hash=$(prefetch_pnpm_deps_hash "$latest_version" "$rev" "$source_hash" "$pnpm_version" "$pnpm_hash")

version_data=$(
  jq --null-input \
    --arg version "$latest_version" \
    --arg rev "$rev" \
    --arg hash "$source_hash" \
    --arg pnpmVersion "$pnpm_version" \
    --arg pnpmHash "$pnpm_hash" \
    --arg pnpmDepsHash "$pnpm_deps_hash" \
    '{
      version: $version,
      rev: $rev,
      hash: $hash,
      pnpmVersion: $pnpmVersion,
      pnpmHash: $pnpmHash,
      pnpmDepsHash: $pnpmDepsHash
    }'
)

build_candidate "$repository_root" "$package_file" "$version_data"
write_json_data "$hashes_file" "$version_data"
echo "Updated dsh-desktop to $latest_version"
