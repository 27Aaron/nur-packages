set shell := ["bash", "-euo", "pipefail", "-c"]

# Format the repository.
fmt:
    nix fmt

# Run the complete local validation suite.
check:
    ./scripts/check.sh

# Update package versions and hashes.
update:
    nix run path:.#update-sources

# Update the generated README package table.
readme:
    nix run path:.#update-readme

# Build cacheable paths with the locked nixpkgs and upload them to Attic.
cache system="":
    NUR_CACHE_SYSTEM="{{ system }}" nix build --impure --no-link --print-out-paths \
        --expr 'let requested = builtins.getEnv "NUR_CACHE_SYSTEM"; system = if requested == "" then builtins.currentSystem else requested; repository = builtins.getFlake ("path:" + toString ./.); in (import ./ci.nix { pkgs = repository.inputs.nixpkgs.legacyPackages.${system}; }).cachePaths' \
        | attic push cache:nur-packages --stdin
