{ pkgs }:
let
  files = import ../support/discover.nix { directory = ./.; };
in
builtins.mapAttrs (_name: path: import path { inherit pkgs; }) files
