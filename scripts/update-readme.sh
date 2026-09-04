#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

usage() {
  echo "Usage: $0 [--check]" >&2
}

check_mode=false
case $# in
  0) ;;
  1)
    if [[ $1 != "--check" ]]; then
      usage
      exit 2
    fi
    check_mode=true
    ;;
  *)
    usage
    exit 2
    ;;
esac

repository_root=$(git rev-parse --show-toplevel)
cd "$repository_root"

readonly readme="$repository_root/README.md"
readonly start_marker='<!--START_SECTION:packages-->'
readonly end_marker='<!--END_SECTION:packages-->'

start_count=0
end_count=0
while IFS= read -r line || [[ -n $line ]]; do
  if [[ $line == "$start_marker" ]]; then
    ((start_count += 1))
  elif [[ $line == "$end_marker" ]]; then
    ((end_count += 1))
  fi
done <"$readme"

if ((start_count != 1 || end_count != 1)); then
  echo "README.md must contain exactly one package section marker pair" >&2
  exit 1
fi

temporary_directory=$(mktemp -d)
new_readme=$(mktemp "$repository_root/.README.md.XXXXXX")
cleanup() {
  rm -rf "$temporary_directory"
  if [[ -n $new_readme ]]; then
    rm -f "$new_readme"
  fi
}
trap cleanup EXIT

readonly package_files="$temporary_directory/package-files"
readonly metadata_file="$temporary_directory/metadata.json"
readonly rows_file="$temporary_directory/rows"
readonly section_file="$temporary_directory/section"

file_status=0
rg --files --null --sort path -g 'package.nix' pkgs/by-name >"$package_files" || file_status=$?
if ((file_status != 0)); then
  if ((file_status == 1)); then
    echo "No packages found below pkgs/by-name" >&2
  fi
  exit "$file_status"
fi

# The interpolation below belongs to Nix, not the shell.
# shellcheck disable=SC2016
nix eval --impure --json --expr '
  let
    repository = builtins.getFlake ("path:" + toString ./.);
    systems = builtins.attrNames repository.packages;
    metadataFor =
      packages:
      builtins.mapAttrs (
        _name: package:
        let
          homepage = package.meta.homepage or "";
        in
        {
          version = package.version or "";
          description = package.meta.description or "";
          homepage =
            if builtins.isList homepage then
              if homepage == [ ] then "" else builtins.head homepage
            else
              homepage;
        }
      ) packages;
    mergeMetadata =
      result: metadata:
      let
        mergeNames =
          merged: names:
          if names == [ ] then
            merged
          else
            let
              name = builtins.head names;
              value = metadata.${name};
              next =
                if builtins.hasAttr name merged then
                  if merged.${name} == value then
                    merged
                  else
                    throw "Package metadata differs between supported systems: ${name}"
                else
                  merged // { ${name} = value; };
            in
            mergeNames next (builtins.tail names);
      in
      mergeNames result (builtins.attrNames metadata);
    mergeAll =
      result: metadataSets:
      if metadataSets == [ ] then
        result
      else
        mergeAll (mergeMetadata result (builtins.head metadataSets)) (builtins.tail metadataSets);
    canonical = mergeAll { } (
      builtins.map (system: metadataFor repository.packages.${system}) systems
    );
  in
  if systems == [ ] then
    throw "The flake exposes no package systems"
  else
    canonical
' >"$metadata_file"

: >"$rows_file"
package_count=0
while IFS= read -r -d '' package_file; do
  package_directory=${package_file%/package.nix}
  package_name=${package_directory##*/}

  jq --exit-status --compact-output \
    --arg name "$package_name" \
    --arg path "$package_directory" \
    '
      def markdown_text:
        tostring
        | gsub("[\\r\\n\\t]+"; " ")
        | gsub("\\|"; "\\\\|");

      .[$name] as $package
      | if $package == null then
          error("Package output is missing: " + $name)
        elif ($package.version // "") == "" then
          error("Package version is missing: " + $name)
        elif ($package.description // "") == "" then
          error("Package description is missing: " + $name)
        elif ($package.homepage // "") == "" then
          error("Package homepage is missing: " + $name)
        else
          {
            name: "[" + ($name | markdown_text) + "](" + $package.homepage + ")",
            path: "[`" + $path + "`](./" + $path + ")",
            version: ($package.version | markdown_text),
            description: ($package.description | markdown_text)
          }
        end
    ' "$metadata_file" >>"$rows_file"

  ((package_count += 1))
done <"$package_files"

{
  printf '\n<details>\n'
  printf '<summary>Package set: (Uncategorized) (%d packages)</summary>\n\n' "$package_count"
  jq --slurp --raw-output '
    def padded($text; $width):
      $text + (" " * ($width - ($text | length)));

    def render_row($cells; $widths):
      "| "
      + (
        [
          range(0; $cells | length) as $index
          | padded($cells[$index]; $widths[$index])
        ]
        | join(" | ")
      )
      + " |";

    . as $packages
    | ["Name", "Path", "Version", "Description"] as $headers
    | ([$headers] + ($packages | map([.name, .path, .version, .description]))) as $rows
    | [
        range(0; $headers | length) as $index
        | ([$rows[][$index] | length] | max)
      ] as $widths
    | render_row($headers; $widths),
      render_row(($widths | map("-" * .)); $widths),
      ($packages[] | render_row([.name, .path, .version, .description]; $widths))
  ' "$rows_file"
  printf '\n</details>\n'
} >"$section_file"

inside_section=false
while IFS= read -r line || [[ -n $line ]]; do
  if [[ $line == "$start_marker" ]]; then
    if [[ $inside_section == true ]]; then
      echo "Nested README package section markers are not allowed" >&2
      exit 1
    fi
    printf '%s\n' "$line" >>"$new_readme"
    cat "$section_file" >>"$new_readme"
    inside_section=true
  elif [[ $line == "$end_marker" ]]; then
    if [[ $inside_section == false ]]; then
      echo "README package section markers are out of order" >&2
      exit 1
    fi
    inside_section=false
    printf '%s\n' "$line" >>"$new_readme"
  elif [[ $inside_section == false ]]; then
    printf '%s\n' "$line" >>"$new_readme"
  fi
done <"$readme"

if [[ $inside_section == true ]]; then
  echo "README package section is not closed" >&2
  exit 1
fi

chmod 0644 "$new_readme"

if cmp -s "$readme" "$new_readme"; then
  echo "README package table is up to date"
  exit 0
fi

if [[ $check_mode == true ]]; then
  echo "README package table is stale; run scripts/update-readme.sh" >&2
  exit 1
fi

mv "$new_readme" "$readme"
new_readme=""
echo "Updated README package table"
