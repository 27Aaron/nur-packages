set shell := ["bash", "-euo", "pipefail", "-c"]

# Build cacheable package outputs and upload them to Attic.
cache:
    nix-build ci.nix -A cacheOutputs --no-out-link \
        | attic push cache:nur-packages --stdin
