{
  pkgs,
  repositoryRoot,
}:
{
  repo-discovery = import ./discover.nix { inherit pkgs; };

  repo-library = import ./library.nix { inherit pkgs; };

  repo-format = pkgs.runCommandLocal "repo-format" { nativeBuildInputs = [ pkgs.nixfmt-tree ]; } ''
    cp -R ${repositoryRoot} source
    chmod -R u+w source
    treefmt --ci --walk filesystem --tree-root "$PWD/source" "$PWD/source"
    touch "$out"
  '';

  repo-shellcheck =
    pkgs.runCommandLocal "repo-shellcheck"
      {
        nativeBuildInputs = [
          pkgs.actionlint
          pkgs.bash
          pkgs.findutils
          pkgs.shellcheck
        ];
      }
      ''
        find ${repositoryRoot} -type f -name '*.sh' -exec bash -n {} +
        find ${repositoryRoot} -type f -name '*.sh' \
          ! -path '*/scripts/update-lib.sh' \
          -exec shellcheck --shell=bash --external-sources --source-path=SCRIPTDIR {} +
        actionlint ${repositoryRoot}/.github/workflows/*.yml
        touch "$out"
      '';

  repo-update-app = import ../support/update-sources-package.nix { inherit pkgs; };
}
