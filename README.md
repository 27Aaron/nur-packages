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
