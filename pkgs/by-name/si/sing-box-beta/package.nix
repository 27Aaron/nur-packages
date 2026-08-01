{
  sing-box,
  fetchFromGitHub,
}:

sing-box.overrideAttrs (finalAttrs: _previousAttrs: {
  pname = "sing-box-beta";
  version = "1.14.0-beta.4";

  src = fetchFromGitHub {
    owner = "SagerNet";
    repo = "sing-box";
    tag = "v${finalAttrs.version}";
    hash = "sha256-1/TgXZZy7sdyGwpmSPdGA36pWdXwfk3ICDBbvcEfdu8=";
  };

  vendorHash = "sha256-+JnXZHwPDQp0fnL/EhXjBUElS6nY1kJ5rNq3RvNP67c=";
})
