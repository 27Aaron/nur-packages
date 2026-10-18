{
  buildGoLatestModule,
  bun,
  fetchFromGitHub,
  lib,
  makeBinaryWrapper,
  stdenv,
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

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    makeBinaryWrapper
  ];

  # 終端機版，不連結圖形介面。
  tags = [ "nogui" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  # 上游測試涵蓋圖形介面，這裡只做安裝檢查。
  doCheck = false;

  # NixOS 無法執行 magpie 下載的 Bun，改用 nixpkgs 的。
  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram "$out/bin/magpie" \
      --set MAGPIE_BUN ${lib.getExe bun}
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$(mktemp -d)
    "$out/bin/magpie" --version | grep -F "magpie ${finalAttrs.version}"
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    grep -q ${lib.getExe bun} "$out/bin/magpie"
  ''
  + ''
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
