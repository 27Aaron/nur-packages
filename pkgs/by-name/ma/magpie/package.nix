{
  buildGoLatestModule,
  fetchFromGitHub,
  lib,
  versionData ? builtins.fromJSON (builtins.readFile ./hashes.json),
}:

buildGoLatestModule (finalAttrs: {
  pname = "magpie";
  inherit (versionData) version;

  src = fetchFromGitHub {
    owner = "yetone";
    repo = "magpie";
    tag = "v${finalAttrs.version}";
    inherit (versionData) hash;
  };

  vendorHash = versionData.vendorHash;

  subPackages = [ "." ];

  env.CGO_ENABLED = "0";

  # The desktop build links a platform webview. This package is the
  # terminal-only binary from `make cli`.
  tags = [ "nogui" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  # The upstream suite is large and covers the GUI. The install check verifies
  # the binary that this package actually ships.
  doCheck = false;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$(mktemp -d)
    "$out/bin/magpie" --version | grep -F "magpie ${finalAttrs.version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Every agent's model. One place.";
    homepage = "https://github.com/yetone/magpie";
    changelog = "https://github.com/yetone/magpie/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "magpie";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
