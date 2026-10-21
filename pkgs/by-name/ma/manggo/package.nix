{
  autoPatchelfHook,
  dbus,
  dpkg,
  fetchurl,
  fontconfig,
  freetype,
  gcc-unwrapped,
  glib,
  krb5,
  lib,
  libdrm,
  libgbm,
  libGL,
  libpulseaudio,
  libx11,
  libxcb,
  libxcb-cursor,
  libxcb-image,
  libxcb-keysyms,
  libxcb-render-util,
  libxcb-util,
  libxcb-wm,
  libxext,
  libxkbcommon,
  libxrandr,
  makeWrapper,
  openssl,
  stdenv,
  versionData ? builtins.fromJSON (builtins.readFile ./hashes.json),
  wayland,
  zlib,
  zstd,
}:

let
  inherit (stdenv.hostPlatform) system;

  debArchitecture = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  };

  # Everything below the top level of the bundle is resolved at runtime:
  # Qt discovers its platform, image format and TLS plugins through the
  # qt.conf shipped next to the binary, and those plugins in turn need the
  # XCB, Wayland and GL stacks. Nothing in that chain is linked directly, so
  # the wrapper has to provide all of it.
  runtimeLibraries = [
    dbus
    fontconfig
    freetype
    gcc-unwrapped.lib
    gcc-unwrapped.libgcc
    glib
    krb5
    libdrm
    libgbm
    libGL
    libpulseaudio
    libx11
    libxcb
    libxcb-cursor
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-util
    libxcb-wm
    libxext
    libxkbcommon
    libxrandr
    openssl
    wayland
    zlib
    zstd
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "manggo";
  inherit (versionData) version;

  src = fetchurl {
    url = "https://gitcode.com/Pylogmon/Manggo/releases/download/${finalAttrs.version}/manggo_${finalAttrs.version}_${debArchitecture.${system}}.deb";
    hash = versionData.hashes.${system};
  };

  # Upstream ships a self-contained tree with its own Qt 6.9, FFmpeg, ICU,
  # ONNX Runtime and PaddleOCR models. Those files are kept byte for byte:
  # they were linked against each other, and stripping them would also drop
  # the RPATHs that let them find one another.
  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    # Used by the bundled sherpa-onnx library.
    gcc-unwrapped.lib
    gcc-unwrapped.libgcc
    krb5
    libGL
    libx11
    libxkbcommon
    openssl
    wayland
    zlib
    zstd
  ];

  unpackPhase = ''
    runHook preUnpack

    dpkg-deb --extract "$src" .
    while IFS= read -r -d "" archive; do
      tar --extract --file "$archive" --no-same-owner
      rm -- "$archive"
    done < <(find . -name "data.tar.*" -print0)

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -d "$out/lib" "$out/bin" "$out/share"
    cp -a usr/lib/manggo "$out/lib/manggo"
    cp -a usr/share/. "$out/share/"

    install -Dm644 usr/share/doc/Manggo/LICENSE \
      "$out/share/licenses/manggo/LICENSE"
    install -Dm644 usr/share/doc/Manggo/USER_AGREEMENT.zh-CN.txt \
      "$out/share/licenses/manggo/USER_AGREEMENT.zh-CN.txt"
    install -Dm644 usr/share/doc/Manggo/PRIVACY_POLICY.zh-CN.txt \
      "$out/share/licenses/manggo/PRIVACY_POLICY.zh-CN.txt"

    makeWrapper "$out/lib/manggo/bin/Manggo" "$out/bin/manggo" \
      --suffix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibraries}"

    runHook postInstall
  '';

  # autoPatchelf may only touch the application binaries. The bundled Qt,
  # FFmpeg, ICU and ONNX Runtime libraries are left alone and the plugins are
  # found through qt.conf, so they are not patched either.
  dontAutoPatchelf = true;
  postFixup = ''
    addAutoPatchelfSearchPath --no-recurse \
      "$out/lib/manggo" "$out/lib/manggo/bin" "$out/lib/manggo/plugins"
    autoPatchelf --no-recurse "$out/lib/manggo/bin"

    # Desktop entries, icons and MIME data all name the upstream binary.
    ln -s manggo "$out/bin/Manggo"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test -x "$out/bin/manggo"
    test -f "$out/lib/manggo/bin/qt.conf"
    test -f "$out/lib/manggo/bin/models/paddleocr/pp-ocrv6-small/PP-OCRv6_small_det.onnx"

    runHook postInstallCheck
  '';

  meta = {
    description = "Desktop translation and screenshot OCR assistant";
    longDescription = ''
      Manggo provides input translation, selection translation, screenshot
      translation, screenshot OCR and text-to-speech from a single desktop
      application. Screenshot OCR runs on-device with the bundled PaddleOCR
      models.
    '';
    homepage = "https://manggo.pylogmon.cn/";
    downloadPage = "https://manggo.pylogmon.cn/#download";
    # The application itself is proprietary; the bundled third-party
    # components keep their own licenses, which upstream ships next to the
    # documentation.
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "manggo";
    maintainers = [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
