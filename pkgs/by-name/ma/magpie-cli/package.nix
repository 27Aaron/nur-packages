{
  lib,
  stdenvNoCC,
  fetchurl,
  makeBinaryWrapper,
  bun,
  xdg-utils,
  versionCheckHook,
  # Name nixpkgs' Bun instead of letting magpie download one at runtime: what
  # it downloads is a glibc build, which a NixOS cannot start.
  withBun ? true,
  versionData ? builtins.fromJSON (builtins.readFile ./hashes.json),
}:

let
  inherit (versionData) version;

  # The release repository names the CLI assets after Go's GOOS/GOARCH
  # pairs. This package takes the linux builds only; the darwin, android,
  # windows, and GUI builds are left out.
  goarch =
    if stdenvNoCC.hostPlatform.isAarch64 then
      "arm64"
    else if stdenvNoCC.hostPlatform.isx86_64 then
      "amd64"
    else
      throw "magpie-cli has no release asset for ${stdenvNoCC.hostPlatform.system}";
  assetName = "magpie-cli-linux-${goarch}";

  # The assets carry no license text, and redistributing an MIT binary
  # requires it, so fetch it from the source tag the release was built from.
  licenseFile = fetchurl {
    url = "https://raw.githubusercontent.com/yetone/magpie/v${version}/LICENSE";
    hash = versionData.licenseHash;
  };
in

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "magpie-cli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/yetone/magpie-releases/releases/download/v${version}/${assetName}";
    hash =
      versionData.assetHashes.${assetName}
        or (throw "magpie-cli has no recorded hash for ${assetName}; run its updater");
  };

  dontUnpack = true;

  # Upstream builds the CLI assets with the `nogui` tag and no cgo, so they
  # are static and run as-is; the wrapper only carries environment overrides.
  nativeBuildInputs = lib.optionals (withBun || stdenvNoCC.hostPlatform.isLinux) [
    makeBinaryWrapper
  ];

  installPhase = ''
    runHook preInstall

    install -Dm0755 "${finalAttrs.src}" "$out/bin/magpie"
    install -Dm0644 "${licenseFile}" "$out/share/licenses/${finalAttrs.pname}/LICENSE"

    runHook postInstall
  '';

  postFixup = lib.optionalString (withBun || stdenvNoCC.hostPlatform.isLinux) ''
    wrapProgram "$out/bin/magpie" \
      ${lib.optionalString withBun "--set MAGPIE_BUN ${lib.getExe bun}"} \
      ${lib.optionalString stdenvNoCC.hostPlatform.isLinux "--prefix PATH : ${lib.makeBinPath [ xdg-utils ]}"}
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";
  # `magpie --version` touches its config directory, so give the check a
  # throwaway HOME and let versionCheckHook pass it through its clean
  # environment.
  versionCheckKeepEnvironment = "HOME";
  preInstallCheck = ''
    export HOME=$(mktemp -d)
  '';

  # $out only holds copies of the two fetched files, so its closure references
  # neither fetchurl output. The binary cache must retain them separately, or
  # a deleted upstream release becomes a dead link for future rebuilds.
  passthru.cachePaths = [
    finalAttrs.src
    licenseFile
  ];

  meta = {
    description = "Pick the model each AI coding agent on your machine uses";
    homepage = "https://usemagpie.ai/";
    changelog = "https://github.com/yetone/magpie-releases/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "magpie";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
