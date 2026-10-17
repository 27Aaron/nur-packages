{
  bashInteractive,
  buildNpmPackage,
  fetchurl,
  jq,
  lib,
  makeWrapper,
  nodejs,
  runCommand,
  versionCheckHook,
  versionData ? builtins.fromJSON (builtins.readFile ./hashes.json),
}:

let
  inherit (versionData) version;

  tarball = fetchurl {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${version}.tgz";
    hash = versionData.hash;
  };

  # 發布的套件沒有 lockfile。devDependencies 只供測試使用，
  # 移除後 npm ci 才能對上內嵌的正式環境 lock。
  src = runCommand "dsh-source" { nativeBuildInputs = [ jq ]; } ''
    mkdir -p "$out"
    tar -xzf ${tarball} -C "$out" --strip-components=1
    jq 'del(.devDependencies)' "$out/package.json" > "$out/package.json.tmp"
    mv "$out/package.json.tmp" "$out/package.json"
    cp ${./package-lock.json} "$out/package-lock.json"
  '';
in
buildNpmPackage (finalAttrs: {
  pname = "dsh";
  inherit version src;

  # 快取 packument。npmDepsHash 對應 fetcher 第 2 版。
  npmDepsFetcherVersion = 2;
  npmDepsHash = versionData.npmDepsHash;

  dontNpmBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    # NixOS 上沒有 /bin/bash。
    substituteInPlace \
      "$out/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-terminal-bash/lib/index.js" \
      --replace-fail '"/bin/bash"' '"${lib.getExe bashInteractive}"'

    # 預先建置的 require-builtin 附加元件會解碼 V8 機器碼，nixpkgs 的 Node 會拒絕。
    # --expose-internals 讓一般的 require() 可以運作。
    for file in index.js worker/profile-resolution-bootstrap.js; do
      substituteInPlace \
        "$out/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-app-boot/lib/$file" \
        --replace-fail 'createRequire(import.meta.url)("node-addon-require-builtin")' \
        '{ requireBuiltin: createRequire(import.meta.url) }'
    done

    rm "$out/bin/dsh"
    makeWrapper ${lib.getExe nodejs} "$out/bin/dsh" \
      --argv0 dsh \
      --add-flags "--expose-internals" \
      --add-flags "$out/lib/node_modules/@deepseek-ai/dsh/lib/bin.js"
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "DeepSeek Harness agent CLI and local Web UI";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    changelog = "https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
