{
  lib,
  stdenv,
  fetchFromGitHub,
  buildGoModule,
  pkg-config,
  wrapGAppsHook3,
  gtk3,
  webkitgtk_4_1,
  xdg-utils,
  glib-networking,
  bun,
  makeBinaryWrapper,
  copyDesktopItems,
  makeDesktopItem,
  versionCheckHook,
  # Name nixpkgs' Bun instead of letting magpie download one: what it
  # downloads is a glibc build, which a NixOS cannot start.
  withBun ? true,
  # false builds the terminal-only magpie-cli: no cgo, the `nogui` tag.
  gui ? true,
  versionData ? builtins.fromJSON (builtins.readFile ./hashes.json),
}:

buildGoModule (finalAttrs: {
  pname = if gui then "magpie" else "magpie-cli";
  inherit (versionData) version;

  src = fetchFromGitHub {
    owner = "yetone";
    repo = "magpie";
    tag = "v${finalAttrs.version}";
    hash = versionData.sourceHash;
  };

  # Both builds share go.sum, so they share this hash.
  vendorHash = versionData.vendorHash;

  subPackages = [ "." ];

  # Makes magpie coexist with the Nix store: the autostart entry names the
  # wrapper that carries MAGPIE_BUN and the GTK environment, the package owns
  # magpie://, and a release build refuses to replace its own store path.
  patches = [ ./nix-support.patch ];

  # The wrapper's path only exists at build time, so the patch leaves a
  # placeholder for it.
  postPatch = ''
    substituteInPlace internal/autostart/autostart.go \
      --replace-fail '@self@' "$out/bin/magpie"
  '';

  env = {
    CGO_ENABLED = if gui then "1" else "0";
  }
  // lib.optionalAttrs (gui && stdenv.hostPlatform.isDarwin) {
    # Wails passes -mmacosx-version-min=10.13. This SDK's linker clamps that
    # to 11.0, while the objects are built for darwinMinVersion, so ld warns
    # on every file. Upstream's 12.0 is still older than these objects.
    CGO_CFLAGS = "-mmacosx-version-min=${stdenv.hostPlatform.darwinMinVersion}";
    CGO_LDFLAGS = "-mmacosx-version-min=${stdenv.hostPlatform.darwinMinVersion}";
  };

  # The Makefile's TAGS. `gtk3` picks GTK 3 and WebKitGTK 4.1 over Wails'
  # default GTK 4 and WebKitGTK 6.
  tags =
    if gui then
      [ "production" ] ++ lib.optionals stdenv.hostPlatform.isLinux [ "gtk3" ]
    else
      [ "nogui" ];

  # `magpie version` prints this, without the tag's leading v, as the
  # release workflow stamps it. update.Released() then treats the build as
  # one that may update itself; the patches above refuse that for a store path.
  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  nativeBuildInputs =
    lib.optionals (gui && stdenv.hostPlatform.isLinux) [
      pkg-config
      wrapGAppsHook3
      copyDesktopItems
    ]
    # Linux GUI is wrapped by wrapGAppsHook3. The CLI always needs a wrapper
    # on Linux (xdg-open), and any build that pins Bun needs one too.
    ++
      lib.optionals
        (
          (!gui && (withBun || stdenv.hostPlatform.isLinux))
          || (gui && stdenv.hostPlatform.isDarwin && withBun)
        )
        [
          makeBinaryWrapper
        ];

  buildInputs = lib.optionals (gui && stdenv.hostPlatform.isLinux) [
    gtk3
    webkitgtk_4_1
    # libsoup's HTTPS is the GIO TLS module. Without it the window loads
    # local pages, then fails every remote image and request.
    glib-networking
  ];

  # The upstream tests drive a real GUI, a real keychain and real agent
  # configs; the install check covers the packaged binary instead.
  doCheck = false;

  # registerScheme returns before writing: the desktop entry and icons it
  # would put into $HOME on first start are installed by this package instead.
  desktopItems = lib.optionals (gui && stdenv.hostPlatform.isLinux) [
    (makeDesktopItem {
      name = "magpie";
      desktopName = "magpie";
      genericName = "Model picker";
      comment = "Every agent's model. One place.";
      exec = "magpie %u";
      icon = "magpie";
      terminal = false;
      categories = [
        "Development"
        "Utility"
      ];
      mimeTypes = [ "x-scheme-handler/magpie" ];
      startupWMClass = "magpie";
    })
  ];

  postInstall =
    lib.optionalString (gui && stdenv.hostPlatform.isLinux) ''
      install -Dm644 internal/gui/icon-256.png \
        "$out/share/icons/hicolor/256x256/apps/magpie.png"
      install -Dm644 internal/gui/icon-1024.png \
        "$out/share/icons/hicolor/1024x1024/apps/magpie.png"
      install -Dm644 build/icon/magpie.svg \
        "$out/share/icons/hicolor/scalable/apps/magpie.svg"
    ''
    # What `make app` does: the URL scheme, autostart and self-update all
    # look for a bundle.
    + lib.optionalString (gui && stdenv.hostPlatform.isDarwin) ''
      app="$out/Applications/magpie.app"
      mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
      mv "$out/bin/magpie" "$app/Contents/MacOS/magpie"
      ln -s "$app/Contents/MacOS/magpie" "$out/bin/magpie"
      cp build/darwin/magpie.icns build/darwin/Assets.car \
        "$app/Contents/Resources/"
      substitute build/darwin/Info.plist "$app/Contents/Info.plist" \
        --replace-fail '@VERSION@' '${finalAttrs.version}' \
        --replace-fail \
          '<key>LSMinimumSystemVersion</key><string>12.0</string>' \
          '<key>LSMinimumSystemVersion</key><string>${stdenv.hostPlatform.darwinMinVersion}</string>'
    ''
    + ''
      install -Dm644 LICENSE "$out/share/licenses/${finalAttrs.pname}/LICENSE"
    '';

  # wrapGAppsHook3 reads gappsWrapperArgs in preFixup.
  preFixup =
    # copyDesktopItems runs after postInstall, so the entry is pinned to the
    # wrapper here. A bare `magpie` would lose to ~/.local/bin/magpie from
    # the upstream installer and miss this wrapper's environment.
    lib.optionalString (gui && stdenv.hostPlatform.isLinux) ''
      chmod +w "$out/share/applications/magpie.desktop"
      substituteInPlace "$out/share/applications/magpie.desktop" \
        --replace-fail 'Exec=magpie %u' "Exec=$out/bin/magpie %u"
      gappsWrapperArgs+=(
        --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}
      )
    ''
    + lib.optionalString (gui && stdenv.hostPlatform.isLinux && withBun) ''
      gappsWrapperArgs+=(--set MAGPIE_BUN ${lib.getExe bun})
    '';

  postFixup =
    lib.optionalString (gui && stdenv.hostPlatform.isDarwin && withBun) ''
      # Inside the bundle, so launchd and LaunchServices both run the wrapper.
      wrapProgram "$out/Applications/magpie.app/Contents/MacOS/magpie" \
        --set MAGPIE_BUN ${lib.getExe bun}
    ''
    + lib.optionalString (!gui && (withBun || stdenv.hostPlatform.isLinux)) ''
      wrapProgram "$out/bin/magpie" \
        ${lib.optionalString withBun "--set MAGPIE_BUN ${lib.getExe bun}"} \
        ${lib.optionalString stdenv.hostPlatform.isLinux "--prefix PATH : ${lib.makeBinPath [ xdg-utils ]}"}
    ''
    # After the wrapper exists. A linker signature does not seal Info.plist
    # or the resources, so codesign rejects the bundle.
    + lib.optionalString (gui && stdenv.hostPlatform.isDarwin) ''
      /usr/bin/codesign --force --sign - "$out/Applications/magpie.app"
    '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  # A linker signature covers neither Info.plist nor the resources, so the
  # bundle has to be signed again after wrapping and must still verify.
  installCheckPhase = ''
    runHook preInstallCheck
  ''
  + lib.optionalString (gui && stdenv.hostPlatform.isDarwin) ''
    app="$out/Applications/magpie.app"
    /usr/bin/codesign --verify --deep --strict "$app"
    grep -F '<string>${stdenv.hostPlatform.darwinMinVersion}</string>' "$app/Contents/Info.plist"
  ''
  + ''
    runHook postInstallCheck
  '';

  # Same line for both, as the Homebrew formula and cask have.
  meta = {
    description = "Pick the model each AI coding agent on your machine uses";
    homepage = "https://usemagpie.ai/";
    changelog = "https://github.com/yetone/magpie/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "magpie";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
