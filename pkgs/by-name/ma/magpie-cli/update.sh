#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(git -C "$script_directory" rev-parse --show-toplevel)
# shellcheck source=../../../../scripts/update-lib.sh
source "$repository_root/scripts/update-lib.sh"

readonly hashes_file="$script_directory/hashes.json"
readonly release_api="https://api.github.com/repos/yetone/magpie-releases/releases/latest"
readonly package_file="pkgs/by-name/ma/magpie-cli/package.nix"
# The package builds the two linux release assets; the release also
# publishes darwin, android, windows, and GUI builds that this package does
# not target.
readonly assets=(
  magpie-cli-linux-amd64
  magpie-cli-linux-arm64
)

release=$(github_api "$release_api")
latest_version=$(jq --exit-status --raw-output '
  select(.draft == false and .prerelease == false)
  | .tag_name
  | capture("^v(?<version>[0-9]+\\.[0-9]+\\.[0-9]+)$").version
' <<<"$release")
current_version=$(jq --exit-status --raw-output .version "$hashes_file")

if [[ $current_version == "$latest_version" ]]; then
  echo "magpie-cli is already up to date ($current_version)"
  exit 0
fi

if ! jq --exit-status --null-input \
  --arg current "$current_version" \
  --arg latest "$latest_version" '
    def parts: split(".") | map(tonumber);
    ($latest | parts) > ($current | parts)
  ' >/dev/null; then
  echo "Refusing to downgrade magpie-cli from $current_version to $latest_version" >&2
  exit 1
fi

echo "Updating magpie-cli from $current_version to $latest_version"

# The release ships a SHA256SUMS listing, and GitHub computes a digest for
# every asset on upload. Both must agree before any hash is recorded, so a
# stale or hand-edited checksum file fails the update here instead of at
# package build time.
checksums=$(curl --fail --silent --show-error --location \
  "https://github.com/yetone/magpie-releases/releases/download/v${latest_version}/SHA256SUMS")

asset_hashes=$(jq --exit-status --null-input --raw-output \
  --argjson release "$release" \
  --arg checksums "$checksums" '
    ($release.assets | map({key: .name, value: .digest}) | from_entries) as $digests
    | ($checksums
      | split("\n")
      | map(select(length > 0))
      | map(split("  ") | {key: .[1], value: .[0]})
      | from_entries) as $sums
    | $ARGS.positional[]
    | . as $asset
    | if $sums | has($asset) then . else error("SHA256SUMS does not list \($asset)") end
    | if $digests | has($asset) then . else error("the release API lists no digest for \($asset)") end
    | if ($sums[$asset] | test("^[0-9a-f]{64}$")) then .
      else error("SHA256SUMS has a malformed entry for \($asset)")
      end
    | if $digests[$asset] == "sha256:" + $sums[$asset] then .
      else error("the API digest for \($asset) disagrees with SHA256SUMS")
      end
    | "\($asset)\t\($sums[$asset])"
' \
  --args "${assets[@]}" \
  | while IFS=$'\t' read -r asset hex; do
      printf '%s\t%s\n' "$asset" "$(nix hash convert --hash-algo sha256 --to sri "$hex")"
    done \
  | jq --exit-status --raw-input --slurp '
      split("\n")
      | map(select(length > 0))
      | map(split("\t") | {key: .[0], value: .[1]})
      | from_entries')

license_hash=$(prefetch_hash \
  "https://raw.githubusercontent.com/yetone/magpie/v${latest_version}/LICENSE" flat)

version_data=$(jq --exit-status --null-input \
  --arg version "$latest_version" \
  --arg licenseHash "$license_hash" \
  --argjson assetHashes "$asset_hashes" \
  '{ version: $version, assetHashes: $assetHashes, licenseHash: $licenseHash }')

build_candidate "$repository_root" "$package_file" "$version_data"
write_json_data "$hashes_file" "$version_data"
echo "Updated magpie-cli to $latest_version"
