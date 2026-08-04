{
  description = "Aaron's personal Nix package repository";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
    in
    {
      legacyPackages = forAllSystems (
        system:
        import ./default.nix {
          pkgs = import nixpkgs { inherit system; };
        }
      );
      packages = forAllSystems (
        system: lib.filterAttrs (_: lib.isDerivation) self.legacyPackages.${system}
      );
      checks = forAllSystems (system: self.packages.${system});
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
      apps = forAllSystems (
        system:
        import ./apps {
          pkgs = import nixpkgs { inherit system; };
        }
      );
      lib = import ./lib { inherit lib; };
      overlays = import ./overlays;
      nixosModules = import ./nixos-modules;
      homeModules = import ./home-modules;
      darwinModules = import ./darwin-modules;
      flakeModules = import ./flake-modules;
    };
}
