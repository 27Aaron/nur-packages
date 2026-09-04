{
  pkgs ? import <nixpkgs> { },
}:
let
  packages = import ./pkgs { inherit pkgs; };
  reservedNames = import ./support/reserved-names.nix;
  specialOutputs = {
    lib = import ./lib { inherit (pkgs) lib; };
    overlays = import ./overlays;
  };
  specialNames = builtins.attrNames specialOutputs;
  specialNamesMatch = specialNames == builtins.sort builtins.lessThan reservedNames;
  collisions = builtins.filter (name: builtins.hasAttr name packages) reservedNames;
in
if !specialNamesMatch then
  throw "support/reserved-names.nix does not match the repository's special outputs"
else if collisions != [ ] then
  throw "Packages use reserved names: ${builtins.concatStringsSep ", " collisions}"
else
  packages // specialOutputs
