#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(git -C "$script_directory" rev-parse --show-toplevel)
# shellcheck source=../../../../scripts/update-lib.sh
source "$repository_root/scripts/update-lib.sh"

readonly hashes_file="$script_directory/hashes.json"
readonly repository_url="https://github.com/SagerNet/sing-box.git"

tags=$(
  git ls-remote --tags --refs "$repository_url" \
    | sed -n 's|^[^[:space:]]*[[:space:]]refs/tags/||p'
)
latest_tag=$(jq --raw-input --slurp --exit-status --raw-output '
  [
    split("\n")[]
    | try capture("^(?<tag>v(?<major>[0-9]+)\\.(?<minor>[0-9]+)\\.(?<patch>[0-9]+)-beta\\.(?<beta>[0-9]+))$") catch empty
    | . + {
        major: (.major | tonumber),
        minor: (.minor | tonumber),
        patch: (.patch | tonumber),
        beta: (.beta | tonumber)
      }
  ]
  | max_by([.major, .minor, .patch, .beta])
  | .tag
' <<<"$tags")
latest_version=${latest_tag#v}
current_version=$(jq --exit-status --raw-output .version "$hashes_file")

if [[ $current_version == "$latest_version" ]]; then
  echo "sing-box-beta is already up to date ($current_version)"
  exit 0
fi

if ! jq --exit-status --null-input \
  --arg current "$current_version" \
  --arg latest "$latest_version" '
    def parts:
      capture("^(?<major>[0-9]+)\\.(?<minor>[0-9]+)\\.(?<patch>[0-9]+)-beta\\.(?<beta>[0-9]+)$")
      | [.major, .minor, .patch, .beta]
      | map(tonumber);
    ($latest | parts) > ($current | parts)
  ' >/dev/null; then
  echo "Refusing to downgrade sing-box-beta from $current_version to $latest_version" >&2
  exit 1
fi

echo "Updating sing-box-beta from $current_version to $latest_version"
source_url="https://github.com/SagerNet/sing-box/archive/refs/tags/${latest_tag}.tar.gz"
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
  "pkgs/by-name/si/sing-box-beta/package.nix" \
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

build_candidate "$repository_root" "pkgs/by-name/si/sing-box-beta/package.nix" "$version_data"
write_json_data "$hashes_file" "$version_data"
echo "Updated sing-box-beta to $latest_version"
