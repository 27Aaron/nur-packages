{
  sing-box,
  fetchFromGitHub,
}:

sing-box.overrideAttrs (finalAttrs: _previousAttrs: {
  pname = "sing-box-beta";
  version = "1.14.0-beta.5";

  src = fetchFromGitHub {
    owner = "SagerNet";
    repo = "sing-box";
    tag = "v${finalAttrs.version}";
    hash = "sha256-9s6C7F5LVGKkr65FIuUM32hkUbXUlC4MGINNSBdWykc=";
  };

  vendorHash = "sha256-djkEuzNVT9MRFHm2F6O+wBqEZd5LXH0kdZqd2qSy8iQ=";
})
