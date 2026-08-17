{
  sing-box,
  sources,
}:
sing-box.overrideAttrs (
  _finalAttrs: _previousAttrs: {
    pname = "sing-box-beta";
    inherit (sources.sing-box-beta) version src;

    vendorHash = "sha256-9Cv3WJG2C3yMk1d8UCLMIhgM5Q9dYAYp7A0F1LdZm/s=";
  }
)
