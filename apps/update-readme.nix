{ pkgs }:
let
  updateReadme = import ../support/update-readme-package.nix { inherit pkgs; };
in
{
  type = "app";
  program = pkgs.lib.getExe updateReadme;
}
