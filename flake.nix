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
      pkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
      repositorySource = builtins.path {
        name = "nur-packages-source";
        path = ./.;
        filter =
          path: _type:
          let
            name = builtins.baseNameOf path;
          in
          name != ".git" && name != "result" && !lib.hasPrefix "result-" name;
      };
      checksFor =
        system:
        let
          packageChecks = self.packages.${system};
          repositoryChecks = import ./checks {
            pkgs = pkgsFor.${system};
            repositoryRoot = repositorySource;
          };
          collisions = builtins.attrNames (builtins.intersectAttrs packageChecks repositoryChecks);
        in
        if collisions != [ ] then
          throw "Packages collide with repository checks: ${lib.concatStringsSep ", " collisions}"
        else
          packageChecks // repositoryChecks;
    in
    {
      legacyPackages = forAllSystems (
        system:
        import ./default.nix {
          pkgs = pkgsFor.${system};
        }
      );
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor.${system};
        in
        lib.filterAttrs (
          _name: package: lib.isDerivation package && lib.meta.availableOn pkgs.stdenv.hostPlatform package
        ) self.legacyPackages.${system}
      );
      checks = forAllSystems checksFor;
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
      apps = forAllSystems (
        system:
        import ./apps {
          pkgs = pkgsFor.${system};
        }
      );
      lib = import ./lib { inherit lib; };
      overlays = import ./overlays;
    };
}
