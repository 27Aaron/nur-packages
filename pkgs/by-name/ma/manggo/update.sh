#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(git -C "$script_directory" rev-parse --show-toplevel)
# shellcheck source=../../../../scripts/update-lib.sh
source "$repository_root/scripts/update-lib.sh"

readonly hashes_file="$script_directory/hashes.json"
readonly package_file="pkgs/by-name/ma/manggo/package.nix"
readonly release_api="https://api.gitcode.com/api/v5/repos/Pylogmon/Manggo/releases?per_page=100"

# GitCode redirects its stable release URLs to short-lived signed CDN links
# and only serves the release listing to browser user agents. It also omits
# the "draft" field entirely instead of reporting drafts explicitly.
releases=$(
  curl --fail --silent --show-error --location \
    --header "Accept: application/json" \
    --user-agent "Mozilla/5.0 (X11; Linux x86_64) Chrome/120" \
    "$release_api"
)

latest_version=$(jq --exit-status --raw-output '
  map(select(.prerelease != true))
  | map(.tag_name | capture("^v?(?<version>[0-9]+\\.[0-9]+\\.[0-9]+)$").version)
  | sort_by(split(".") | map(tonumber))
  | last
' <<<"$releases")
current_version=$(jq --exit-status --raw-output .version "$hashes_file")

if [[ $current_version == "$latest_version" ]]; then
  echo "manggo is already up to date ($current_version)"
  exit 0
fi

if ! jq --exit-status --null-input \
  --arg current "$current_version" \
  --arg latest "$latest_version" '
    def parts: split(".") | map(tonumber);
    ($latest | parts) > ($current | parts)
  ' >/dev/null; then
  echo "Refusing to downgrade manggo from $current_version to $latest_version" >&2
  exit 1
fi

echo "Updating manggo from $current_version to $latest_version"

# Upstream publishes one Debian package per architecture.
hashes=$(jq --null-input '{}')
for pair in x86_64-linux:amd64 aarch64-linux:arm64; do
  system=${pair%%:*}
  architecture=${pair##*:}
  source_url="https://gitcode.com/Pylogmon/Manggo/releases/download/${latest_version}/manggo_${latest_version}_${architecture}.deb"
  source_hash=$(prefetch_hash "$source_url")
  hashes=$(jq --arg system "$system" --arg hash "$source_hash" \
    '. + { ($system): $hash }' <<<"$hashes")
done

dummy_hashes=$(jq --null-input --arg hash "$dummy_sha256" \
  '{ "x86_64-linux": $hash, "aarch64-linux": $hash }')
dummy_data=$(jq --null-input \
  --arg version "$latest_version" \
  --argjson hashes "$dummy_hashes" \
  '{ version: $version, hashes: $hashes }')

build_log=$(mktemp)
cleanup() {
  rm -f "$build_log"
}
trap cleanup EXIT

if build_candidate "$repository_root" "$package_file" "$dummy_data" >"$build_log" 2>&1; then
  echo "The dummy source hashes unexpectedly succeeded" >&2
  exit 1
fi

if ! rg --fixed-strings --quiet "specified: $dummy_sha256" "$build_log"; then
  echo "The candidate build failed before checking the source hashes:" >&2
  tail -n 120 "$build_log" >&2
  exit 1
fi

version_data=$(jq --null-input \
  --arg version "$latest_version" \
  --argjson hashes "$hashes" \
  '{ version: $version, hashes: $hashes }')

build_candidate "$repository_root" "$package_file" "$version_data"
write_json_data "$hashes_file" "$version_data"
echo "Updated manggo to $latest_version"
