#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(git -C "$script_directory" rev-parse --show-toplevel)
# shellcheck source=../../../../scripts/update-lib.sh
source "$repository_root/scripts/update-lib.sh"

readonly hashes_file="$script_directory/hashes.json"
readonly release_api="https://api.github.com/repos/locez/kotonoha/releases/latest"
readonly package_file="pkgs/by-name/ko/kotonoha/package.nix"

release=$(github_api "$release_api")
latest_version=$(jq --exit-status --raw-output '
  select(.draft == false and .prerelease == false)
  | .tag_name
  | capture("^v(?<version>[0-9]+\\.[0-9]+\\.[0-9]+)$").version
' <<<"$release")
current_version=$(jq --exit-status --raw-output '
  .version
  | strings
  | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
' "$hashes_file")

if [[ $current_version == "$latest_version" ]]; then
  echo "kotonoha is already up to date ($current_version)"
  exit 0
fi

if ! jq --exit-status --null-input \
  --arg current "$current_version" \
  --arg latest "$latest_version" '
    def parts: split(".") | map(tonumber);
    ($latest | parts) > ($current | parts)
  ' >/dev/null; then
  echo "Refusing to downgrade kotonoha from $current_version to $latest_version" >&2
  exit 1
fi

echo "Updating kotonoha from $current_version to $latest_version"
source_url="https://github.com/locez/kotonoha/archive/refs/tags/v${latest_version}.tar.gz"
source_hash=$(prefetch_hash "$source_url" unpack)

version_data=$(jq --null-input \
  --arg version "$latest_version" \
  --arg hash "$source_hash" \
  '{ version: $version, hash: $hash }')

build_candidate "$repository_root" "$package_file" "$version_data"
write_json_data "$hashes_file" "$version_data"
echo "Updated kotonoha to $latest_version"
