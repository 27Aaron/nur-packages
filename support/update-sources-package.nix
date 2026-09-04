{ pkgs }:
pkgs.writeShellApplication {
  name = "update-sources";
  runtimeInputs = with pkgs; [
    bash
    coreutils
    curl
    gitMinimal
    gnused
    jq
    nix
    ripgrep
  ];
  text = builtins.readFile ../scripts/update-sources.sh;
}
