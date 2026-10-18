#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(git -C "$script_directory" rev-parse --show-toplevel)
# shellcheck source=../../../../scripts/update-lib.sh
source "$repository_root/scripts/update-lib.sh"

readonly cli_hashes_file="$script_directory/hashes.json"
readonly desktop_hashes_file="$script_directory/../magpie-desktop/hashes.json"
readonly release_api="https://api.github.com/repos/yetone/magpie/releases/latest"
readonly cli_package_file="pkgs/by-name/ma/magpie/package.nix"
readonly desktop_package_file="pkgs/by-name/ma/magpie-desktop/package.nix"

release=$(github_api "$release_api")
latest_version=$(jq --exit-status --raw-output '
  select(.draft == false and .prerelease == false)
  | .tag_name
  | capture("^v(?<version>[0-9]+\\.[0-9]+\\.[0-9]+)$").version
' <<<"$release")
current_version=$(jq --exit-status --raw-output .version "$cli_hashes_file")
desktop_version=$(jq --exit-status --raw-output .version "$desktop_hashes_file")

if [[ $current_version != "$desktop_version" ]]; then
  echo "magpie and magpie-desktop hashes disagree ($current_version vs $desktop_version)" >&2
  exit 1
fi

if [[ $current_version == "$latest_version" ]]; then
  echo "magpie is already up to date ($current_version)"
  exit 0
fi

if ! jq --exit-status --null-input \
  --arg current "$current_version" \
  --arg latest "$latest_version" '
    def parts: split(".") | map(tonumber);
    ($latest | parts) > ($current | parts)
  ' >/dev/null; then
  echo "Refusing to downgrade magpie from $current_version to $latest_version" >&2
  exit 1
fi

echo "Updating magpie from $current_version to $latest_version"
source_url="https://github.com/yetone/magpie/archive/refs/tags/v${latest_version}.tar.gz"
source_hash=$(prefetch_hash "$source_url" unpack)

build_log=$(mktemp)
cleanup() {
  rm -f "$build_log"
}
trap cleanup EXIT

candidate_data=$(jq --null-input \
  --arg version "$latest_version" \
  --arg hash "$source_hash" \
  --arg vendorHash "$dummy_sha256" \
  '{ version: $version, hash: $hash, vendorHash: $vendorHash }')

if build_candidate \
  "$repository_root" \
  "$cli_package_file" \
  "$candidate_data" >"$build_log" 2>&1; then
  echo "The dummy vendorHash unexpectedly succeeded" >&2
  exit 1
fi

if ! rg --fixed-strings --quiet "specified: $dummy_sha256" "$build_log"; then
  echo "The candidate build failed before checking vendorHash:" >&2
  tail -n 120 "$build_log" >&2
  exit 1
fi

vendor_hash=$(
  sed -n "/specified: $dummy_sha256/,/got:/ { s/^.*got:[[:space:]]*//p; }" "$build_log" \
    | head -n 1
)
if [[ ! $vendor_hash =~ ^sha256-[A-Za-z0-9+/]{43}=$ ]]; then
  echo "Could not extract vendorHash from the failed build:" >&2
  tail -n 120 "$build_log" >&2
  exit 1
fi

version_data=$(jq --null-input \
  --arg version "$latest_version" \
  --arg hash "$source_hash" \
  --arg vendorHash "$vendor_hash" \
  '{ version: $version, hash: $hash, vendorHash: $vendorHash }')

build_candidate "$repository_root" "$cli_package_file" "$version_data"
build_candidate "$repository_root" "$desktop_package_file" "$version_data"
write_json_data "$cli_hashes_file" "$version_data"
write_json_data "$desktop_hashes_file" "$version_data"
echo "Updated magpie and magpie-desktop to $latest_version"
