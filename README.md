<div align="center">
  <img src="https://img.shields.io/badge/Aaron%27s%20NUR%20Packages-5277C3.svg?style=for-the-badge&logo=nixos&logoColor=white" height="28" alt="Aaron's NUR Packages">
</div>

<p align="center">
  <img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/palette/macchiato.png" width="400" alt="Catppuccin Macchiato palette">
</p>

<p align="center">
  <a href="https://github.com/27Aaron/nur-packages/stargazers"><img alt="Stargazers" src="https://img.shields.io/github/stars/27Aaron/nur-packages?style=for-the-badge&logo=starship&color=C9CBFF&logoColor=D9E0EE&labelColor=302D41"></a>
  <a href="https://github.com/27Aaron/nur-packages/forks"><img alt="Forks" src="https://img.shields.io/github/forks/27Aaron/nur-packages?style=for-the-badge&logo=forgejo&color=F2CDCD&logoColor=D9E0EE&labelColor=302D41"></a>
  <a href="https://github.com/27Aaron/nur-packages/commits/"><img alt="Commit activity" src="https://img.shields.io/github/commit-activity/y/27Aaron/nur-packages?style=for-the-badge&logo=upptime&color=B5E8E0&logoColor=D9E0EE&labelColor=302D41"></a>
</p>

Personal Nix packages built against `nixpkgs-unstable`, with both flake outputs
and classic NUR-compatible entry points.

## Packages

| Package | Description |
| --- | --- |
| `geolite2` | MaxMind GeoLite2 ASN, City, and Country databases |
| `sing-box-beta` | Current beta release of the sing-box proxy platform |

Supported systems are `aarch64-darwin` and `x86_64-linux`.

## Usage

Try or build a package directly:

```console
nix run github:27Aaron/nur-packages#sing-box-beta -- version
nix build github:27Aaron/nur-packages#geolite2
```

The GeoLite derivation installs these files in its output root:

```text
GeoLite2-ASN.mmdb
GeoLite2-City.mmdb
GeoLite2-Country.mmdb
```

As a flake input:

```nix
{
  inputs.aaron-nur.url = "github:27Aaron/nur-packages";

  outputs =
    { nixpkgs, aaron-nur, ... }:
    {
      nixosConfigurations.example = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({ pkgs, ... }: {
            environment.systemPackages = [
              aaron-nur.packages.${pkgs.stdenv.hostPlatform.system}.sing-box-beta
            ];
          })
        ];
      };
    };
}
```

Or apply the default overlay and use `pkgs.sing-box-beta` or `pkgs.geolite2`:

```nix
nixpkgs.overlays = [ inputs.aaron-nur.overlays.default ];
```

The classic entry point remains available after cloning the repository:

```console
nix-build -A geolite2
```

## Binary cache

Add the binary cache to a NixOS or nix-darwin configuration:

```nix
{
  nix.settings = {
    extra-substituters = [
      "https://cache.ou.al/nur-packages"
    ];
    extra-trusted-public-keys = [
      "nur-packages:UOog+J0xYx60NaFjo0eU+IR0mdadY/jjExRorV0L38M="
    ];
  };
}
```

With an authenticated Attic client, `just cache` uploads the current system's
cacheable paths using the locked nixpkgs. `just cache x86_64-linux` targets a
configured Linux builder. GeoLite sources are uploaded separately because their
upstream releases are short-lived; Attic must retain them permanently for old
revisions to remain buildable.

## Maintenance

Mutable package pins live beside each package in `hashes.json`. A normal source
update changes only those JSON files:

```console
nix run .#update-sources
```

Each updater calculates candidate hashes and completes a candidate build before
atomically replacing its `hashes.json`. Run the full validation suite with:

```console
just check
```

For normal pull-request checks on automated updates, configure `UPDATE_PR_TOKEN`
as a fine-grained token with repository contents and pull-request write access.
When the workflow falls back to `GITHUB_TOKEN`, GitHub does not trigger another
workflow run from the created pull request; the source update has still completed
the full validation suite before publication. The update workflow does not upload
to Attic. Run the cache recipe (`just cache`) while the referenced GeoLite release
is still available.

## Thanks

- [Lantian's NUR](https://github.com/xddxdd/nur-packages)
