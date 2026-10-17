{
  callPackage,
  copyDesktopItems,
  desktop-file-utils,
  electron,
  fetchurl,
  lib,
  makeDesktopItem,
  makeWrapper,
  stdenv,
}:

let
  # 同層套件不在作用域內，直接匯入 CLI。
  dsh = callPackage ../dsh/package.nix { };
  icon = fetchurl {
    url = "https://raw.githubusercontent.com/deepseek-ai/deepseek-harness/dsh-v${dsh.version}/apps/desktop/resources/icon.png";
    hash = "sha256-mCwoWVaNg9JXYRClJ8VF8EZB9ACL2yz+tnWPMzwPsHo=";
  };
in

# 上游 electron-builder 只針對 Windows 與 macOS。這是包住官方 `dsh web`
# 執行環境的原生視窗，並共用 $DSH_HOME。
stdenv.mkDerivation (finalAttrs: {
  pname = "dsh-desktop";
  inherit (dsh) version;

  strictDeps = true;
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    copyDesktopItems
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/dsh-desktop" "$out/share/icons/hicolor/1024x1024/apps"
    cp ${./main.cjs} "$out/lib/dsh-desktop/main.cjs"
    cp ${icon} "$out/lib/dsh-desktop/icon.png"
    cp ${icon} "$out/share/icons/hicolor/1024x1024/apps/dsh-desktop.png"

    # Electron 可以直接載入指令碼路徑，因此不需要 package.json。
    makeWrapper ${lib.getExe electron} "$out/bin/dsh-desktop" \
      --add-flags "--class=dsh-desktop" \
      --add-flags "--ozone-platform-hint=auto" \
      --add-flags "$out/lib/dsh-desktop/main.cjs" \
      --prefix PATH : ${lib.makeBinPath [ dsh ]}

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "dsh-desktop";
      desktopName = "DeepSeek Harness";
      comment = "DeepSeek Harness desktop window";
      exec = "dsh-desktop %U";
      icon = "dsh-desktop";
      terminal = false;
      type = "Application";
      categories = [ "Development" ];
      startupWMClass = "dsh-desktop";
      keywords = [
        "ai"
        "deepseek"
        "dsh"
      ];
    })
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ desktop-file-utils ];
  installCheckPhase = ''
    runHook preInstallCheck

    test -x "$out/bin/dsh-desktop"
    test -f "$out/lib/dsh-desktop/main.cjs"
    test -s "$out/lib/dsh-desktop/icon.png"
    desktop-file-validate "$out/share/applications/dsh-desktop.desktop"
    grep -q -- '--class=dsh-desktop' "$out/bin/dsh-desktop"
    grep -q -- ${lib.escapeShellArg "${dsh}/bin"} "$out/bin/dsh-desktop"

    runHook postInstallCheck
  '';

  meta = {
    description = "Native desktop window for the DeepSeek Harness Web UI";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    changelog = "https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "dsh-desktop";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
