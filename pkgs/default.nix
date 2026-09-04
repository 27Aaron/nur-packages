{ pkgs }:
let
  inherit (pkgs) lib;
  callPackage = lib.callPackageWith pkgs;
  prefixes = lib.filterAttrs (_name: type: type == "directory") (builtins.readDir ./by-name);
in
lib.foldl' (
  packages: prefix:
  let
    discovered = lib.filesystem.packagesFromDirectoryRecursive {
      inherit callPackage;
      directory = ./by-name/${prefix};
    };
    duplicates = builtins.attrNames (builtins.intersectAttrs packages discovered);
  in
  if duplicates != [ ] then
    throw "Duplicate packages across by-name prefixes: ${lib.concatStringsSep ", " duplicates}"
  else
    packages // discovered
) { } (builtins.attrNames prefixes)
