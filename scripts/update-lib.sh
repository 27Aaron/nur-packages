set -o errexit
set -o nounset
set -o pipefail

readonly dummy_sha256="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
readonly candidate_expression='
  let
    repository = builtins.getFlake ("path:" + builtins.getEnv "NUR_REPOSITORY_ROOT");
    system = builtins.currentSystem;
    pkgs = repository.inputs.nixpkgs.legacyPackages.${system};
    packagePath = repository.outPath + "/" + builtins.getEnv "NUR_PACKAGE_PATH";
    versionData = builtins.fromJSON (builtins.getEnv "NUR_UPDATE_DATA");
  in
  pkgs.callPackage packagePath { inherit versionData; }
'

github_api() {
  local url=$1
  local -a headers=(
    --header "Accept: application/vnd.github+json"
    --header "X-GitHub-Api-Version: 2022-11-28"
  )

  if [[ -n ${GITHUB_TOKEN:-} ]]; then
    headers+=(--header "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  curl --fail --silent --show-error --location "${headers[@]}" "$url"
}

prefetch_hash() {
  local url=$1
  local mode=${2:-flat}
  local -a arguments=(store prefetch-file --json)

  if [[ $mode == unpack ]]; then
    arguments+=(--unpack)
  elif [[ $mode != flat ]]; then
    echo "Unknown prefetch mode: $mode" >&2
    return 2
  fi

  nix "${arguments[@]}" "$url" | jq --exit-status --raw-output .hash
}

build_candidate() {
  local repository_root=$1
  local package_path=$2
  local version_data=$3

  NUR_REPOSITORY_ROOT=$repository_root \
    NUR_PACKAGE_PATH=$package_path \
    NUR_UPDATE_DATA=$version_data \
    nix build --impure --no-link --no-write-lock-file --expr "$candidate_expression"
}

write_json_data() {
  local file=$1
  local data=$2
  local temporary

  temporary=$(mktemp "${file}.tmp.XXXXXX")
  if jq . <<<"$data" >"$temporary"; then
    :
  else
    local status=$?
    rm -f "$temporary"
    return "$status"
  fi

  if chmod 0644 "$temporary"; then
    :
  else
    local status=$?
    rm -f "$temporary"
    return "$status"
  fi

  if mv "$temporary" "$file"; then
    :
  else
    local status=$?
    rm -f "$temporary"
    return "$status"
  fi
}
