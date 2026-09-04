{ pkgs }:
pkgs.writeShellApplication {
  name = "update-readme";
  runtimeInputs = with pkgs; [
    bash
    coreutils
    gitMinimal
    jq
    nix
    ripgrep
  ];
  text = builtins.readFile ../scripts/update-readme.sh;
}
