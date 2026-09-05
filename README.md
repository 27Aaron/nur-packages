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

## Binary cache

Add the binary cache to your NixOS configuration:

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

## Packages

<!--START_SECTION:packages-->

<details>
<summary>Package set: (Uncategorized) (4 packages)</summary>

| Name                                               | Path                                               | Version        | Description                                               |
| -------------------------------------------------- | -------------------------------------------------- | -------------- | --------------------------------------------------------- |
| [bilihud](https://github.com/locez/bilihud)        | [`bilihud`](./pkgs/by-name/bi/bilihud)             | 0.7.1          | Bilibili live-stream danmaku overlay for fullscreen games |
| [geolite2](https://github.com/P3TERX/GeoLite.mmdb) | [`geolite2`](./pkgs/by-name/ge/geolite2)           | 2026.09.04     | MaxMind GeoLite2 ASN, City, and Country databases         |
| [kotonoha](https://github.com/locez/kotonoha)      | [`kotonoha`](./pkgs/by-name/ko/kotonoha)           | 0.2.2          | Linux desktop lyrics overlay for MPRIS players            |
| [sing-box-beta](https://sing-box.sagernet.org)     | [`sing-box-beta`](./pkgs/by-name/si/sing-box-beta) | 1.14.0-beta.17 | Universal proxy platform                                  |

</details>
<!--END_SECTION:packages-->

## Thanks

- [Lantian's NUR](https://github.com/xddxdd/nur-packages)
