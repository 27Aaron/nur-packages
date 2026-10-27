{
  buildGo127Module,
  fetchFromGitHub,
  lib,
  versionData ? builtins.fromJSON (builtins.readFile ./hashes.json),
}:

buildGo127Module (finalAttrs: {
  pname = "cloudflared";
  inherit (versionData) version;

  src = fetchFromGitHub {
    owner = "cloudflare";
    repo = "cloudflared";
    tag = finalAttrs.version;
    inherit (versionData) hash;
  };

  vendorHash = versionData.vendorHash;

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${finalAttrs.version}"
    "-X github.com/cloudflare/cloudflared/cmd/cloudflared/updater.BuiltForPackageManager=nixpkgs"
  ];

  # Upstream tests need raw ICMP sockets. Check the version and the package-manager
  # update lock instead.
  doCheck = false;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    "$out/bin/cloudflared" version | grep -F "${finalAttrs.version}"
    "$out/bin/cloudflared" update 2>&1 | grep -F "cloudflared was installed by nixpkgs"

    runHook postInstallCheck
  '';

  meta = {
    description = "Client for Cloudflare Tunnel, Access, and DNS over HTTPS";
    homepage = "https://github.com/cloudflare/cloudflared";
    changelog = "https://github.com/cloudflare/cloudflared/releases/tag/${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "cloudflared";
    platforms = lib.platforms.unix;
  };
})
