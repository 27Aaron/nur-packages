{
  buildGoLatestModule,
  bun,
  desktop-file-utils,
  fetchFromGitHub,
  gtk3,
  lib,
  pkg-config,
  stdenv,
  versionData ? builtins.fromJSON (builtins.readFile ./hashes.json),
  webkitgtk_4_1,
  wrapGAppsHook3,
  xdg-utils,
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

  # Login autostart records this path. On Linux it is the GTK wrapper, not
  # .magpie-wrapped, which has no GLib or GDK environment. On Darwin it is a
  # symlink into magpie.app; EvalSymlinks then finds the bundle, so launchd
  # can read its Info.plist.
  postPatch = ''
    substituteInPlace internal/autostart/autostart.go \
      --replace-fail 'exe, err := os.Executable()' 'exe, err := "'"$out"'/bin/magpie", error(nil)'
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    # Nix ships the desktop entry, including the magpie:// handler. The copy
    # this writes would name .magpie-wrapped and shadow it. Keep the rest of
    # the file: it moves WebKit's saved page data onto the program name.
    awk '
      /^func registerScheme\(\) error \{$/ {
        print "func registerScheme() error {"
        print "\t// The package provides share/applications/magpie.desktop."
        print "\treturn nil"
        print "}"
        print ""
        skip = 1
        next
      }
      skip && /^\/\/ installIcon / { skip = 0 }
      !skip { print }
    ' internal/gui/scheme_linux.go > internal/gui/scheme_linux.go.new
    mv internal/gui/scheme_linux.go.new internal/gui/scheme_linux.go
    substituteInPlace internal/gui/scheme_linux.go \
      --replace-fail $'\t"strings"\n' "" \
      --replace-fail $'\t"github.com/yetone/magpie/internal/proc"\n' ""
  '';

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

  # MAGPIE_BUN skips the Bun magpie would download. That build is linked for a
  # generic Linux and NixOS will not start it, so plugins fail with exit 127.
  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    gappsWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}
      --set MAGPIE_BUN ${lib.getExe bun}
    )
  '';

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
      app="$out/Applications/magpie.app"
      mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
      mv "$out/bin/magpie" "$app/Contents/MacOS/magpie"
      ln -s "$app/Contents/MacOS/magpie" "$out/bin/magpie"
      cp build/darwin/magpie.icns build/darwin/Assets.car \
        "$app/Contents/Resources/"
      substitute build/darwin/Info.plist "$app/Contents/Info.plist" \
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
    grep -F 'Exec=magpie %u' "$out/share/applications/magpie.desktop"
    grep -F 'x-scheme-handler/magpie' "$out/share/applications/magpie.desktop"
    grep -a -q "$out/bin/magpie" "$out/bin/.magpie-wrapped"
    grep -q ${lib.getExe bun} "$out/bin/magpie"
    test -f "$out/share/icons/hicolor/256x256/apps/magpie.png"
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    app="$out/Applications/magpie.app"
    test -x "$app/Contents/MacOS/magpie"
    test ! -L "$app/Contents/MacOS/magpie"
    test "$(realpath "$out/bin/magpie")" = "$app/Contents/MacOS/magpie"
    test -f "$app/Contents/Info.plist"
    grep -F '${finalAttrs.version}' "$app/Contents/Info.plist"
    grep -F 'magpie' "$app/Contents/Info.plist"
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
