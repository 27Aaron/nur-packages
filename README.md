# Aaron's Nix User Repository

**My personal [NUR](https://github.com/nix-community/NUR) repository**, use it at your own risk.

## Binary cache

Prebuilt packages are available from the public binary cache at
`https://cache.ou.al/nur`.

Add the cache to your NixOS configuration:

```nix
nix.settings = {
  extra-substituters = [
    "https://cache.ou.al/nur"
  ];

  extra-trusted-public-keys = [
    "nur:/d+9TNhlrK0PGhpvyA3tQqqeClJLwUtg0v3wZdtZOKg="
  ];
};
```

Apply the configuration with:

```console
$ sudo nixos-rebuild switch
```

## Package maintenance

Packages under `pkgs/by-name/<prefix>/<name>/package.nix` are registered
automatically. Adding a package does not require editing `default.nix`.

Other repository outputs are discovered from their matching directories:

- `lib/*.nix` files accept `{ lib }` and return attribute sets that are merged
  into `lib`;
- `apps/*.nix` files define runnable flake apps for every supported system;
- `overlays/*.nix` files are exposed by filename, in addition to
  `overlays.default`;
- `nixos-modules`, `home-modules`, `darwin-modules`, and `flake-modules`
  expose each `name.nix` or `name/default.nix` as `name`.

Each directory's `default.nix` is only its discovery entry point and is not
exported as an attribute. Matching file and directory symlinks are supported
for these discovered outputs. Duplicate discovered names or library attributes,
reserved package names, and duplicate packages across prefixes fail evaluation
instead of being overwritten.

External release sources managed by [nvfetcher](https://github.com/berberman/nvfetcher)
are declared in `nvfetcher.toml`. The scheduled `Update package sources` workflow
refreshes `_sources/generated.nix` and opens a pull request when versions or hashes
change.

Run the same update process on an `x86_64-linux` or Apple Silicon macOS host
with:

```console
$ nix run .#update-sources
```

Packages containing dependency hashes such as `vendorHash`, `cargoHash`, or
`npmDepsHash` are discovered automatically and refreshed with nix-update.
Executable package-specific scripts named `update.*` anywhere under
`pkgs/by-name` are also run automatically before dependency hashes are refreshed.

Packages and maintenance apps are available for both `x86_64-linux` and
`aarch64-darwin`.

Format the repository and run its checks with:

```console
$ nix fmt
$ nix flake check
```
