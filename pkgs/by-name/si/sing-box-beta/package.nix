{
  sing-box,
  sources,
}:
sing-box.overrideAttrs (_finalAttrs: _previousAttrs: {
  pname = "sing-box-beta";
  inherit (sources.sing-box-beta) version src;

  vendorHash = "sha256-djkEuzNVT9MRFHm2F6O+wBqEZd5LXH0kdZqd2qSy8iQ=";
})
