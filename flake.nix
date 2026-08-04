{
  description = "My personal NUR repository";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = {
    self,
    nixpkgs,
  }: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux"];
  in {
    legacyPackages = forAllSystems (system:
      import ./default.nix {
        pkgs = import nixpkgs {inherit system;};
      });
    packages = forAllSystems (system: nixpkgs.lib.filterAttrs (_: v: nixpkgs.lib.isDerivation v) self.legacyPackages.${system});
    apps = forAllSystems (
      system: let
        pkgs = import nixpkgs {inherit system;};
        updateSources = pkgs.writeShellApplication {
          name = "update-sources";
          runtimeInputs = with pkgs; [
            coreutils
            nix-update
            nvfetcher
            ripgrep
          ];
          text = ''
            key_args=()
            if [[ -f secrets.toml ]]; then
              key_args=(-k secrets.toml)
            fi

            nvfetcher "''${key_args[@]}" -c nvfetcher.toml

            if [[ -n "$(tail -c 1 _sources/generated.json)" ]]; then
              printf '\n' >> _sources/generated.json
            fi

            while IFS= read -r update_script; do
              if [[ ! -x "$update_script" ]]; then
                echo "Package update script is not executable: $update_script" >&2
                exit 1
              fi
              echo "Running $update_script"
              "$update_script"
            done < <(rg --files -g 'update.*' pkgs/by-name)

            while IFS= read -r package_file; do
              if rg --quiet '(vendor|cargo|npm|pnpm).*(Hash|Sha256)\s*=' "$package_file"; then
                package_name=$(basename "$(dirname "$package_file")")
                nix-update "$package_name" --flake --version=skip
              fi
            done < <(rg --files -g package.nix pkgs/by-name)
          '';
        };
      in {
        update-sources = {
          type = "app";
          program = "${updateSources}/bin/update-sources";
        };
      }
    );
    nixosModules = import ./nixos-modules;
    # homeModules = import ./home-modules;
    # darwinModules = import ./darwin-modules;
    # flakeModules = import ./flake-modules;
  };
}
