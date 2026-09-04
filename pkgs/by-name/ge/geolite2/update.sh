#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(git -C "$script_directory" rev-parse --show-toplevel)
# shellcheck source=../../../../scripts/update-lib.sh
source "$repository_root/scripts/update-lib.sh"

readonly hashes_file="$script_directory/hashes.json"
readonly release_api="https://api.github.com/repos/P3TERX/GeoLite.mmdb/releases/latest"

release=$(github_api "$release_api")
latest_version=$(jq --exit-status --raw-output '.tag_name | select(test("^[0-9]{4}\\.[0-9]{2}\\.[0-9]{2}$"))' <<<"$release")
current_version=$(jq --exit-status --raw-output .version "$hashes_file")

if [[ $current_version == "$latest_version" ]]; then
  echo "geolite2 is already up to date ($current_version)"
  exit 0
fi

if ! jq --exit-status --null-input \
  --arg current "$current_version" \
  --arg latest "$latest_version" \
  'def parts: split(".") | map(tonumber); ($latest | parts) > ($current | parts)' >/dev/null; then
  echo "Refusing to downgrade geolite2 from $current_version to $latest_version" >&2
  exit 1
fi

asset_url() {
  local name=$1
  jq --exit-status --raw-output --arg name "$name" \
    '.assets[] | select(.name == $name) | .browser_download_url' <<<"$release"
}

echo "Updating geolite2 from $current_version to $latest_version"
asn_hash=$(prefetch_hash "$(asset_url GeoLite2-ASN.mmdb)")
city_hash=$(prefetch_hash "$(asset_url GeoLite2-City.mmdb)")
country_hash=$(prefetch_hash "$(asset_url GeoLite2-Country.mmdb)")

version_data=$(jq --null-input \
  --arg version "$latest_version" \
  --arg asn "$asn_hash" \
  --arg city "$city_hash" \
  --arg country "$country_hash" \
  '{ version: $version, hashes: { asn: $asn, city: $city, country: $country } }')

build_candidate "$repository_root" "pkgs/by-name/ge/geolite2/package.nix" "$version_data"
write_json_data "$hashes_file" "$version_data"
echo "Updated geolite2 to $latest_version"
