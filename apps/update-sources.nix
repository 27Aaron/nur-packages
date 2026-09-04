{ pkgs }:
let
  updateSources = import ../support/update-sources-package.nix { inherit pkgs; };
in
{
  type = "app";
  program = pkgs.lib.getExe updateSources;
}
