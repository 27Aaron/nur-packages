# Electron desktop for DeepSeek Harness.
#
# Upstream packages the desktop shell for Windows and macOS only. The application
# itself runs on Linux; this package repeats the assembly step with nixpkgs'
# Electron and links a private monorepo build in as the bundled dsh runtime.
# That build is not a separate package: this repository publishes dsh-desktop only.
{
  lib,
  callPackage,
  bubblewrap,
  electron_44,
  nodejs_24,
  patchelf,
  python312,
  stdenvNoCC,
  vips,
  versionData ? builtins.fromJSON (builtins.readFile ./hashes.json),
}:

let
  inherit (versionData) version pnpmVersion;

  source = callPackage ./source.nix { inherit versionData; };

  nodeRuntimeVersion = nodejs_24.version;

  pythonEnv = python312.withPackages (
    ps: with ps; [
      numpy
      pandas
      python-dateutil
      six
      tzdata
      python-docx
      python-pptx
      openpyxl
      pillow
      lxml
      xlsxwriter
      typing-extensions
      et-xmlfile
    ]
  );

  # Names and versions must satisfy isDistributionMap(): names
  # ^[A-Za-z0-9][A-Za-z0-9._-]*$ and versions ^[0-9][\w.!+-]*$.
  pythonPackages = {
    numpy = python312.pkgs.numpy.version;
    pandas = python312.pkgs.pandas.version;
    python-dateutil = python312.pkgs.python-dateutil.version;
    six = python312.pkgs.six.version;
    tzdata = python312.pkgs.tzdata.version;
    python-docx = python312.pkgs.python-docx.version;
    python-pptx = python312.pkgs.python-pptx.version;
    openpyxl = python312.pkgs.openpyxl.version;
    Pillow = python312.pkgs.pillow.version;
    lxml = python312.pkgs.lxml.version;
    XlsxWriter = python312.pkgs.xlsxwriter.version;
    typing_extensions = python312.pkgs.typing-extensions.version;
    et_xmlfile = python312.pkgs.et-xmlfile.version;
  };

  # Production modules the bundled shell imports by bare name. Build tooling
  # (typescript, vite, electron-builder) stays out. The npm electron package is
  # absent on purpose: main.js resolves "electron" from the runtime.
  appModules = [
    "semver"
    "ws"
    "electron-updater"
    "koffi"
    "sharp"
    "js-yaml"
    "extract-zip"
    "react"
    "react-dom"
    "cos-nodejs-sdk-v5"
    "@deepseek-ai/cordis"
    "@deepseek-ai/dsh-api-gateway"
    "@deepseek-ai/dsh-app-boot"
    "@deepseek-ai/dsh-atomic-write"
    "@deepseek-ai/dsh-client-shortcuts"
    "@deepseek-ai/dsh-client-ui-primitives"
    "@deepseek-ai/dsh-client-ui-settings-general"
    "@deepseek-ai/dsh-client-ui-sidebar-browser"
    "@deepseek-ai/dsh-client-ui-theme"
    "@deepseek-ai/dsh-deepseek-account"
    "@deepseek-ai/dsh-home-paths"
    "@deepseek-ai/node-addon-system"
  ];

  # Host dependencies resolved by bare name at startup. Linked, not copied:
  # pnpm's layout is relative symlinks, and copying the subtree dangles them.
  hostDependencies = [
    "cordis"
    "dsh-agent"
    "dsh-app-boot"
    "dsh-client-connection"
    "dsh-deepseek-account"
    "dsh-home-paths"
    "dsh-host-webserver"
    "dsh-jobs"
    "dsh-schedule"
    "dsh-skill-office"
    "dsh-tool-workspace-dependencies"
    "dsh-workspace"
    "libreoffice-kit"
  ];

  dshRuntimeTree = stdenvNoCC.mkDerivation {
    pname = "dsh-desktop-runtime";
    inherit version;
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/node_modules/@deepseek-ai"
      ln -s ${source}/apps/cli "$out/node_modules/@deepseek-ai/dsh"
      ln -s ${source}/apps/web "$out/node_modules/@deepseek-ai/dsh-web-frontend"
      ln -s ${source}/apps/desktop-host "$out/node_modules/@deepseek-ai/dsh-desktop-host"
      for name in ${lib.concatStringsSep " " hostDependencies}; do
        ln -s "${source}/apps/desktop-host/node_modules/@deepseek-ai/$name" \
          "$out/node_modules/@deepseek-ai/$name"
      done
      cat > "$out/package.json" <<JSON
      {
        "name": "@deepseek-ai/dsh-desktop-runtime",
        "private": true,
        "version": "${version}",
        "type": "module"
      }
      JSON
      runHook postInstall
    '';
  };

  appModulesTree = stdenvNoCC.mkDerivation {
    pname = "dsh-desktop-app-modules";
    inherit version;
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      for name in ${lib.concatStringsSep " " appModules}; do
        mkdir -p "$out/$(dirname "$name")"
        ln -s "${source}/apps/desktop/node_modules/$name" "$out/$name"
      done
      runHook postInstall
    '';
  };

  vipsLib = lib.getLib vips;

  # sharp's addon crashes on the libvips it ships (desktop.nix note 5). Stage a
  # dynamically linked substitute under the exact DT_NEEDED name the addon asks
  # for, and refuse a different upstream series.
  sharpLibvips = stdenvNoCC.mkDerivation {
    pname = "dsh-desktop-sharp-libvips";
    inherit version;

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    nativeBuildInputs = [ patchelf ];

    installPhase = ''
      runHook preInstall
      addon="$(ls ${source}/node_modules/.pnpm/@img+sharp-linux-x64@*/node_modules/@img/sharp-linux-x64/lib/sharp-linux-x64-*.node)"
      if [ "$(printf '%s\n' "$addon" | wc -l)" -ne 1 ]; then
        echo "dsh-desktop: expected exactly one sharp addon, got: $addon" >&2
        exit 1
      fi

      soname="$(patchelf --print-needed "$addon" | grep -E '^libvips-cpp[.]so[.]' || true)"
      if [ -z "$soname" ] || [ "$(printf '%s\n' "$soname" | wc -l)" -ne 1 ]; then
        echo "dsh-desktop: expected one libvips-cpp DT_NEEDED entry in $addon, got: $soname" >&2
        exit 1
      fi

      addon_series="''${soname#libvips-cpp.so.}"
      addon_series="''${addon_series%.*}"
      vips_series="${lib.versions.majorMinor vips.version}"
      if [ "$addon_series" != "$vips_series" ]; then
        echo "dsh-desktop: sharp's addon requires $soname (series $addon_series), but this package links vips ${vips.version} (series $vips_series)" >&2
        exit 1
      fi

      set -- $(find ${vipsLib}/lib -maxdepth 1 -type f -name 'libvips-cpp.so.*')
      if [ "$#" -ne 1 ]; then
        echo "dsh-desktop: expected one libvips-cpp.so.* in ${vipsLib}/lib, found $#" >&2
        exit 1
      fi
      mkdir -p "$out/lib"
      ln -s "$1" "$out/lib/$soname"
      test -e "$out/lib/$soname"
      runHook postInstall
    '';
  };
in
callPackage ./desktop.nix {
  inherit
    lib
    stdenvNoCC
    version
    pnpmVersion
    nodeRuntimeVersion
    pythonPackages
    dshRuntimeTree
    appModulesTree
    sharpLibvips
    ;
  electron = electron_44;
  nodejs = nodejs_24;
  inherit bubblewrap;
  coverageScript = ./desktop-coverage.mjs;
  descriptorScript = ./desktop-runtime-json.mjs;
  shellPatchScript = ./desktop-shell-patch.mjs;
  windowGlassScript = ./desktop-window-glass.mjs;
  identityScript = ./desktop-identity.mjs;
  inspectorWorkerScript = ./desktop-inspector-worker.mjs;
  pnpmEntryScript = ./desktop-runtime-pnpm.mjs;
  hostManifest = "${source}/apps/desktop-host/package.json";
  protocolSource = "${source}/apps/desktop/src/host-protocol.ts";
  python = pythonEnv;
  pythonVersion = python312.version;
  appRoot = "${source}/apps/desktop";
  pnpmRoot = "${source}/node_modules/pnpm";
  skillOfficeAssets = "${source}/packages/skill/skill-office/assets";
}
