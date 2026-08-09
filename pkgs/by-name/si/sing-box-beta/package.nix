{
  sing-box,
  sources,
}:
sing-box.overrideAttrs (
  _finalAttrs: _previousAttrs: {
    pname = "sing-box-beta";
    inherit (sources.sing-box-beta) version src;

    vendorHash = "sha256-4F3p5ENJcf0/c9C5aYaqJXhprq9sD+f156YZOsuSlNk=";
  }
)
