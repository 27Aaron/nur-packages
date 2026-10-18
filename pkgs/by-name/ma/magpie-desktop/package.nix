{
  buildGoLatestModule,
  desktop-file-utils,
  fetchFromGitHub,
  gtk3,
  lib,
  pkg-config,
  stdenv,
  versionData ? builtins.fromJSON (builtins.readFile ./hashes.json),
  webkitgtk_4_1,
  wrapGAppsHook3,
}:

buildGoLatestModule (finalAttrs: {
  pname = "magpie-desktop";
  inherit (versionData) version;

  src = fetchFromGitHub {
    owner = "yetone";
    repo = "magpie";
    tag = "v${finalAttrs.version}";
    inherit (versionData) hash;
  };

  vendorHash = versionData.vendorHash;

  subPackages = [ "." ];

  env.CGO_ENABLED = "1";

  # Linux links GTK 3 and WebKitGTK 4.1. Darwin uses the system webview, so it
  # does not take the gtk3 tag. `production` is the upstream desktop build.
  tags = [
    "production"
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ "gtk3" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    desktop-file-utils
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    gtk3
    webkitgtk_4_1
  ];

  postInstall =
    lib.optionalString stdenv.hostPlatform.isLinux ''
      install -Dm644 internal/gui/icon-256.png \
        "$out/share/icons/hicolor/256x256/apps/magpie.png"
      install -Dm644 internal/gui/icon-1024.png \
        "$out/share/icons/hicolor/1024x1024/apps/magpie.png"
      install -Dm644 build/icon/magpie.svg \
        "$out/share/icons/hicolor/scalable/apps/magpie.svg"
      install -Dm644 ${./magpie.desktop} \
        "$out/share/applications/magpie.desktop"
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      mkdir -p "$out/Applications/magpie.app/Contents/MacOS" \
        "$out/Applications/magpie.app/Contents/Resources"
      ln -s "$out/bin/magpie" "$out/Applications/magpie.app/Contents/MacOS/magpie"
      cp build/darwin/magpie.icns build/darwin/Assets.car \
        "$out/Applications/magpie.app/Contents/Resources/"
      substitute build/darwin/Info.plist \
        "$out/Applications/magpie.app/Contents/Info.plist" \
        --replace-fail '@VERSION@' '${finalAttrs.version}'
    '';

  doCheck = false;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$(mktemp -d)
    "$out/bin/magpie" --version | grep -F "magpie ${finalAttrs.version}"
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    desktop-file-validate "$out/share/applications/magpie.desktop"
    test -f "$out/share/icons/hicolor/256x256/apps/magpie.png"
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    test -x "$out/Applications/magpie.app/Contents/MacOS/magpie"
    test -f "$out/Applications/magpie.app/Contents/Info.plist"
    grep -F '${finalAttrs.version}' "$out/Applications/magpie.app/Contents/Info.plist"
  ''
  + ''
    runHook postInstallCheck
  '';

  meta = {
    description = "Menu bar app for switching any agent's model";
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
