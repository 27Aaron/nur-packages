{ pkgs }:
let
  updateSources = pkgs.writeShellApplication {
    name = "update-sources";
    runtimeInputs = with pkgs; [
      coreutils
      nix-update
      nvfetcher
      ripgrep
    ];
    text = builtins.readFile ../scripts/update-sources.sh;
  };
in
{
  type = "app";
  program = "${updateSources}/bin/update-sources";
}
