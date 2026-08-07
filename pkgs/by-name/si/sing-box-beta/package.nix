{
  sing-box,
  sources,
}:
sing-box.overrideAttrs (
  _finalAttrs: _previousAttrs: {
    pname = "sing-box-beta";
    inherit (sources.sing-box-beta) version src;

    vendorHash = "sha256-Oxcl4YvPEQFhsljUFqQ9GJRkOz6OHlfuN3tA7eLeB8Y=";
  }
)
