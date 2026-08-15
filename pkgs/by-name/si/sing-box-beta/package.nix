{
  sing-box,
  sources,
}:
sing-box.overrideAttrs (
  _finalAttrs: _previousAttrs: {
    pname = "sing-box-beta";
    inherit (sources.sing-box-beta) version src;

    vendorHash = "sha256-4MtT1e8OQBo7kp0pZ7AnQwru3CRGdcSdLSrb3jGUxK0=";
  }
)
