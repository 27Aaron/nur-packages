# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `overlays`,
# `nixosModules`, `homeModules`, `darwinModules` and `flakeModules`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage
{pkgs ? import <nixpkgs> {}}: let
  inherit (pkgs) lib;

  sources = pkgs.callPackage ./_sources/generated.nix {};
  callPackage = lib.callPackageWith (pkgs // {inherit sources;});

  packagePrefixes = lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./pkgs/by-name);
  packages = lib.foldl' (
    result: prefix:
      result
      // lib.filesystem.packagesFromDirectoryRecursive {
        inherit callPackage;
        directory = ./pkgs/by-name/${prefix};
      }
  ) {} (builtins.attrNames packagePrefixes);
in
  packages
  // {
    # The `lib`, `overlays`, `nixosModules`, `homeModules`,
    # `darwinModules` and `flakeModules` names are special
    lib = import ./lib {inherit pkgs;}; # functions
    nixosModules = import ./nixos-modules; # NixOS modules
    # homeModules = { }; # Home Manager modules
    # darwinModules = { }; # nix-darwin modules
    # flakeModules = { }; # flake-parts modules
    overlays = import ./overlays; # nixpkgs overlays
  }
