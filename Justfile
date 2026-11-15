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
