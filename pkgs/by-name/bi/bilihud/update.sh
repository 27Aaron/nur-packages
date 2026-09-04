#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(git -C "$script_directory" rev-parse --show-toplevel)
# shellcheck source=../../../../scripts/update-lib.sh
source "$repository_root/scripts/update-lib.sh"

readonly hashes_file="$script_directory/hashes.json"
readonly release_api="https://api.github.com/repos/locez/bilihud/releases/latest"
readonly package_file="pkgs/by-name/bi/bilihud/package.nix"

release=$(github_api "$release_api")
latest_version=$(jq --exit-status --raw-output \
  '.tag_name | capture("^v(?<version>[0-9]+\\.[0-9]+\\.[0-9]+)$").version' <<<"$release")
current_version=$(jq --exit-status --raw-output .version "$hashes_file")

if [[ $current_version == "$latest_version" ]]; then
  echo "bilihud is already up to date ($current_version)"
  exit 0
fi

if ! jq --exit-status --null-input \
  --arg current "$current_version" \
  --arg latest "$latest_version" \
  'def parts: split(".") | map(tonumber); ($latest | parts) > ($current | parts)' >/dev/null; then
  echo "Refusing to downgrade bilihud from $current_version to $latest_version" >&2
  exit 1
fi

echo "Updating bilihud from $current_version to $latest_version"
build_log=$(mktemp)
cleanup() {
  rm -f "$build_log"
}
trap cleanup EXIT

candidate_data=$(jq --null-input \
  --arg version "$latest_version" \
  --arg hash "$dummy_sha256" \
  '{ version: $version, hash: $hash }')

if build_candidate "$repository_root" "$package_file" "$candidate_data" >"$build_log" 2>&1; then
  echo "The dummy source hash unexpectedly succeeded" >&2
  exit 1
fi

if ! rg --fixed-strings --quiet "specified: $dummy_sha256" "$build_log"; then
  echo "The candidate build failed before checking the source hash:" >&2
  tail -n 120 "$build_log" >&2
  exit 1
fi

source_hash=$(
  sed -n "/specified: $dummy_sha256/,/got:/ { s/^.*got:[[:space:]]*//p; }" "$build_log" \
    | head -n 1
)
if [[ ! $source_hash =~ ^sha256-[A-Za-z0-9+/]{43}=$ ]]; then
  echo "Could not extract the source hash from the failed build:" >&2
  tail -n 120 "$build_log" >&2
  exit 1
fi

version_data=$(jq --null-input \
  --arg version "$latest_version" \
  --arg hash "$source_hash" \
  '{ version: $version, hash: $hash }')

build_candidate "$repository_root" "$package_file" "$version_data"
write_json_data "$hashes_file" "$version_data"
echo "Updated bilihud to $latest_version"
