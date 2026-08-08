{
  sing-box,
  sources,
}:
sing-box.overrideAttrs (
  _finalAttrs: _previousAttrs: {
    pname = "sing-box-beta";
    inherit (sources.sing-box-beta) version src;

    vendorHash = "sha256-l5vNu/JhZRLvXyD2sWPS4qVaTSgmzDQadsNwwF4Ucnw=";
  }
)
