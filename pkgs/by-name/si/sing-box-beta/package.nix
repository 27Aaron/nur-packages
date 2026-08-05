{
  sing-box,
  sources,
}:
sing-box.overrideAttrs (
  _finalAttrs: _previousAttrs: {
    pname = "sing-box-beta";
    inherit (sources.sing-box-beta) version src;

    vendorHash = "sha256-QDRLNatY0PHhM1GGusK/SOlCAK1le9Bf3t3Ns8rPG0Q=";
  }
)
