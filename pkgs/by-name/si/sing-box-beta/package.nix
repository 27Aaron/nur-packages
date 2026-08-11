{
  sing-box,
  sources,
}:
sing-box.overrideAttrs (
  _finalAttrs: _previousAttrs: {
    pname = "sing-box-beta";
    inherit (sources.sing-box-beta) version src;

    vendorHash = "sha256-DF2eegNt5i/ymmJzef2vKQ9djbTUP3n8d5YxMqd8td0=";
  }
)
