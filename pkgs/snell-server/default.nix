{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  upx,
  gcc,
  ...
}:
stdenv.mkDerivation rec {
  pname = "snell-server";
  version = "5.0.1";

  src = let
    sources = {
      "x86_64-linux" = {
        url = "https://dl.nssurge.com/snell/snell-server-v${version}-linux-amd64.zip";
        hash = "sha256-m+ocK541tzsxY0hWwE0Yw5MHK55dzeajJ4HYuPkIxTk=";
      };
      "aarch64-linux" = {
        url = "https://dl.nssurge.com/snell/snell-server-v${version}-linux-aarch64.zip";
        hash = "sha256-LxeL9axGjOGhMEVO+kCgYD+75OR+zEiAqYn0q8f4JM8=";
      };
    };
    source =
      sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported architecture: ${stdenv.hostPlatform.system}");
  in
    fetchurl source;

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
    upx
  ];

  buildInputs = [gcc.cc.lib];

  unpackPhase = ''
    runHook preUnpack
    unzip "$src"
    upx -d snell-server
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 snell-server "$out/bin/snell-server"
    runHook postInstall
  '';

  meta = {
    description = "Lean encrypted proxy protocol developed by the Surge team";
    homepage = "https://kb.nssurge.com/surge-knowledge-base/release-notes/snell";
    license = lib.licenses.unfree;
    mainProgram = "snell-server";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
  };
}
