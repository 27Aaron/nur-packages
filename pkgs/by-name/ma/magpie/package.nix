{
  lib,
  stdenvNoCC,
  makeDesktopItem,
  copyDesktopItems,
  imagemagick,
  autoPatchelfHook,
  wrapGAppsHook3,
  gtk3,
  webkitgtk_4_1,
  bun,
  xdg-utils,
  fetchurl,
  versionCheckHook,
  # Name nixpkgs' Bun instead of letting magpie download one at runtime: what
  # it downloads is a glibc build, which a NixOS cannot start.
  withBun ? true,
  versionData ? builtins.fromJSON (builtins.readFile ./hashes.json),
}:

let
  inherit (versionData) version;

  # The release repository names the GUI assets after Go's GOOS/GOARCH
  # pairs. This package takes the linux builds only; the darwin and windows
  # builds are left out.
  goarch =
    if stdenvNoCC.hostPlatform.isAarch64 then
      "arm64"
    else if stdenvNoCC.hostPlatform.isx86_64 then
      "amd64"
    else
      throw "magpie has no release asset for ${stdenvNoCC.hostPlatform.system}";
  assetName = "magpie-linux-${goarch}";

  # The assets carry no license text, and redistributing an MIT binary
  # requires it, so fetch it from the source tag the release was built from.
  licenseFile = fetchurl {
    url = "https://raw.githubusercontent.com/yetone/magpie/v${version}/LICENSE";
    hash = versionData.licenseHash;
  };

  iconFile = fetchurl {
    url = "https://raw.githubusercontent.com/yetone/magpie/v${version}/internal/gui/icon-1024.png";
    hash = versionData.iconHash;
  };
in

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "magpie";
  inherit version;

  src = fetchurl {
    url = "https://github.com/yetone/magpie-releases/releases/download/v${version}/${assetName}";
    hash =
      versionData.assetHashes.${assetName}
        or (throw "magpie has no recorded hash for ${assetName}; run its updater");
  };

  dontUnpack = true;

  # Upstream builds the GUI assets against GTK 3 and WebKitGTK 4.1, so the
  # prebuilt binary needs those patched in, and the desktop entry needs the
  # GNOME wrapper for a working environment.
  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
    copyDesktopItems
    imagemagick
  ];
  buildInputs = [
    gtk3
    webkitgtk_4_1
  ];

  installPhase = ''
    runHook preInstall

    install -Dm0755 "${finalAttrs.src}" "$out/bin/magpie"
    install -Dm0644 "${licenseFile}" "$out/share/licenses/${finalAttrs.pname}/LICENSE"

    magick "${iconFile}" -resize 512x512 icon.png
    install -Dm0644 icon.png "$out/share/icons/hicolor/512x512/apps/magpie.png"

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}
      ${lib.optionalString withBun "--set MAGPIE_BUN ${lib.getExe bun}"}
    )
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "magpie";
      desktopName = "magpie";
      comment = "Every agent's model. One place.";
      exec = "magpie %u";
      icon = "magpie";
      startupWMClass = "magpie";
      terminal = false;
      categories = [
        "Development"
        "Utility"
      ];
      mimeTypes = [ "x-scheme-handler/magpie" ];
    })
  ];

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

  # $out only holds copies of the fetched files, so its closure references
  # neither fetchurl output. The binary cache must retain them separately, or
  # a deleted upstream release becomes a dead link for future rebuilds.
  passthru.cachePaths = [
    finalAttrs.src
    licenseFile
    iconFile
  ];

  meta = {
    description = "Manage models, providers, and accounts for AI coding agents in one place";
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
