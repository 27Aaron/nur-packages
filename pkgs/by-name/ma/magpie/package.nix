{
  lib,
  stdenv,
  fetchFromGitHub,
  buildGoModule,
  pkg-config,
  wrapGAppsHook3,
  gtk3,
  webkitgtk_4_1,
  desktop-file-utils,
  xdg-utils,
  glib-networking,
  bun,
  makeBinaryWrapper,
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

  # The wrapper is what carries MAGPIE_BUN and the GTK environment, so what
  # magpie records about itself for a later launch — the autostart entry — has
  # to name the wrapper, not the .magpie-wrapped binary it runs. On Darwin
  # $out/bin/magpie is a symlink into the bundle; self() resolves it, which
  # lands on the wrapper when one was installed and on the binary otherwise.
  postPatch =
    lib.optionalString (stdenv.hostPlatform.isLinux || stdenv.hostPlatform.isDarwin) ''
      substituteInPlace internal/autostart/autostart.go \
        --replace-fail 'exe, err := os.Executable()' 'exe, err := "'"$out"'/bin/magpie", error(nil)'
    ''
    # On first start magpie would also write a magpie:// handler into $HOME
    # naming that unwrapped binary, shadowing the entry installed below. The
    # package's own entry claims the scheme. Returning first leaves the old
    # body unreachable, so its imports stay used without a rewrite that
    # breaks the next time the function moves.
    + lib.optionalString (gui && stdenv.hostPlatform.isLinux) ''
      substituteInPlace internal/gui/scheme_linux.go \
        --replace-fail 'func registerScheme() error {' 'func registerScheme() error {'$'\n\treturn nil'
    ''
    # A release version may replace itself, and an admin prompt (pkexec,
    # osascript) can write a Nix store that is not mounted read-only.
    # Homebrew is already refused; a store path is too. "nix" is the stuck
    # reason the UI and `magpie update` understand. Every installed copy
    # shares one instance lock, as a Homebrew Cellar build does.
    + ''
      substituteInPlace internal/update/admin.go \
        --replace-fail 'case strings.Contains(bundle, "/AppTranslocation/"):' 'case strings.Contains(bundle, "/nix/store/"):'$'\n\t\treturn "nix"\n\tcase strings.Contains(bundle, "/AppTranslocation/"):'
      substituteInPlace internal/gui/update.go \
        --replace-fail 'func exeStuck(dir string) string {' 'func exeStuck(dir string) string {'$'\n\tif strings.Contains(dir, "/nix/store/") {\n\t\treturn "nix"\n\t}'
      substituteInPlace internal/cli/update_cli.go \
        --replace-fail 'if !update.Released(version) {' 'if exe, err := update.Executable(); err == nil && strings.Contains(exe, "/nix/store/") {'$'\n\t\treturn fmt.Errorf("this magpie was installed with Nix; update that package instead")\n\t}\n\tif !update.Released(version) {'
      substituteInPlace internal/update/cli_path.go \
        --replace-fail 'case "read-only":' 'case "nix":'$'\n\t\treturn nil, errors.New("this magpie was installed with Nix; update that package instead of copying the command")\n\tcase "read-only":'
      substituteInPlace internal/gui/instance_unix.go \
        --replace-fail 'strings.Contains(exe, "/Cellar/magpie/")' 'strings.Contains(exe, "/Cellar/magpie/") || strings.Contains(exe, "/nix/store/")'
      substituteInPlace internal/gui/assets/app.js \
        --replace-fail 'if (u.stuck === "not-writable")' $'if (u.stuck === "nix") return t("this magpie was installed with Nix, so it can\'t update itself; update the package, then restart it.");\n  if (u.stuck === "not-writable")'
      substituteInPlace internal/gui/assets/i18n.js \
        --replace-fail '并重新创建容器。",' '并重新创建容器。",'$'\n    "this magpie was installed with Nix, so it can\'t update itself; update the package, then restart it.": "这个 magpie 由 Nix 安装，无法自行更新；请更新这个包，然后重新打开。",' \
        --replace-fail '並重新建立容器。",' '並重新建立容器。",'$'\n    "this magpie was installed with Nix, so it can\'t update itself; update the package, then restart it.": "這個 magpie 由 Nix 安裝，無法自行更新；請更新這個套件，然後重新開啟。",' \
        --replace-fail 'コンテナを作り直してください。",' 'コンテナを作り直してください。",'$'\n    "this magpie was installed with Nix, so it can\'t update itself; update the package, then restart it.": "この magpie は Nix でインストールされているため、自動アップデートできません。パッケージを更新してから、開き直してください。",' \
        --replace-fail 'erstellen Sie den Container neu.",' 'erstellen Sie den Container neu.",'$'\n    "this magpie was installed with Nix, so it can\'t update itself; update the package, then restart it.": "Dieses magpie wurde mit Nix installiert und kann sich daher nicht selbst aktualisieren; aktualisieren Sie das Paket und starten Sie es neu.",'
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
      desktop-file-utils
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
  # configs; doInstallCheck runs the installed binary instead.
  doCheck = false;

  # registerScheme returns before writing: the entry and icon it would put
  # into $HOME on first start are installed here instead.
  postInstall =
    lib.optionalString (gui && stdenv.hostPlatform.isLinux) ''
      install -Dm644 internal/gui/icon-256.png \
        "$out/share/icons/hicolor/256x256/apps/magpie.png"
      install -Dm644 internal/gui/icon-1024.png \
        "$out/share/icons/hicolor/1024x1024/apps/magpie.png"
      install -Dm644 build/icon/magpie.svg \
        "$out/share/icons/hicolor/scalable/apps/magpie.svg"
      # Absolute Exec: a bare `magpie` would lose to ~/.local/bin/magpie from
      # the upstream installer, and would miss this wrapper's environment.
      mkdir -p "$out/share/applications"
      substitute ${./magpie.desktop} "$out/share/applications/magpie.desktop" \
        --replace-fail 'Exec=magpie %u' "Exec=$out/bin/magpie %u"
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
    lib.optionalString (gui && stdenv.hostPlatform.isLinux) ''
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
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$(mktemp -d)
    "$out/bin/magpie" --version | grep -Fx "magpie ${finalAttrs.version}"
  ''
  + lib.optionalString (gui && stdenv.hostPlatform.isLinux) ''
    desktop-file-validate "$out/share/applications/magpie.desktop"
    grep -F "Exec=$out/bin/magpie %u" "$out/share/applications/magpie.desktop"
    grep -F 'x-scheme-handler/magpie' "$out/share/applications/magpie.desktop"
    grep -F 'Categories=Development;Utility;' "$out/share/applications/magpie.desktop"
    test -f "$out/share/icons/hicolor/256x256/apps/magpie.png"
    grep -q ${lib.getLib glib-networking}/lib/gio/modules "$out/bin/magpie"
  ''
  + lib.optionalString (gui && stdenv.hostPlatform.isDarwin) ''
    app="$out/Applications/magpie.app"
    test -x "$app/Contents/MacOS/magpie"
    test ! -L "$app/Contents/MacOS/magpie"
    test "$(realpath "$out/bin/magpie")" = "$app/Contents/MacOS/magpie"
    grep -F '${finalAttrs.version}' "$app/Contents/Info.plist"
    grep -F '<string>${stdenv.hostPlatform.darwinMinVersion}</string>' "$app/Contents/Info.plist"
    /usr/bin/codesign --verify --deep --strict "$app"
    if [ -e "$app/Contents/MacOS/.magpie-wrapped" ]; then
      linked="$app/Contents/MacOS/.magpie-wrapped"
    else
      linked="$app/Contents/MacOS/magpie"
    fi
    otool -l "$linked" | awk '/LC_BUILD_VERSION/{p=1} p && /minos/{print; exit}' | grep -F '${stdenv.hostPlatform.darwinMinVersion}'
  ''
  + lib.optionalString withBun ''
    grep -q ${lib.getExe bun} "$out/bin/magpie"
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    grep -q ${lib.getBin xdg-utils} "$out/bin/magpie"
  ''
  # The login entry magpie writes has to name the wrapper it was started
  # from; with nothing to wrap, the plain binary is that path. The program
  # also has to refuse to replace a store path.
  + lib.optionalString (stdenv.hostPlatform.isLinux || stdenv.hostPlatform.isDarwin) ''
    if [ -e "$out/bin/.magpie-wrapped" ]; then
      binary="$out/bin/.magpie-wrapped"
    elif [ -e "$out/Applications/magpie.app/Contents/MacOS/.magpie-wrapped" ]; then
      binary="$out/Applications/magpie.app/Contents/MacOS/.magpie-wrapped"
    elif [ -e "$out/Applications/magpie.app/Contents/MacOS/magpie" ]; then
      binary="$out/Applications/magpie.app/Contents/MacOS/magpie"
    else
      binary="$out/bin/magpie"
    fi
    grep -a -q "$out/bin/magpie" "$binary"
    grep -a -q "installed with Nix" "$binary"
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
