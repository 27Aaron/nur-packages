# Internal build of the DeepSeek Harness monorepo. This is not a public package:
# dsh-desktop is the only output, and it links this tree in as the bundled runtime.
{
  lib,
  stdenv,
  bashInteractive,
  fetchFromGitHub,
  fetchPnpmDeps,
  nodejs_24,
  pnpmConfigHook,
  pnpm_11,
  versionData,
}:

let
  pname = "dsh-desktop-source";
  inherit (versionData) version rev;

  pnpm = pnpm_11.override {
    version = versionData.pnpmVersion;
    hash = versionData.pnpmHash;
  };

  # The runtime resolver reaches Node's internal module loader through the
  # prebuilt node-addon-require-builtin binary, which cannot locate V8's
  # builtin_module_require getter in nixpkgs' Node. The desktop Host is started
  # with --expose-internals, so try a plain require first.
  addonRequireBuiltin = "    return api.requireBuiltin(moduleId);";
  addonRequireBuiltinPatched =
    "    if (process.execArgv.includes('--expose-internals')) {\n"
    + "      try { return require(moduleId); } catch (_error) {}\n"
    + "    }\n"
    + "    return api.requireBuiltin(moduleId);";

  # The experimental Inspector starts its Worker with an empty execArgv, which
  # drops the flag above. Pass it explicitly, and only for this Worker.
  inspectorSpawnWorkerExecArgv = "execArgv: []";
  inspectorSpawnWorkerExecArgvPatched = "execArgv: [\"--expose-internals\"]";
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "deepseek-ai";
    repo = "deepseek-harness";
    inherit rev;
    hash = versionData.hash;
  };

  pnpmDeps = fetchPnpmDeps {
    inherit pname version pnpm;
    inherit (finalAttrs) src;
    fetcherVersion = 4;
    hash = versionData.pnpmDepsHash;
  };

  nativeBuildInputs = [
    nodejs_24
    pnpm
    pnpmConfigHook
  ];

  env = {
    CI = "true";
    DSH_TELEMETRY_DISABLED = "1";
    DSH_CLIENT_COMMIT_HASH = rev;
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
  };

  buildPhase = ''
    runHook preBuild
    pnpm run build:official
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -a -T . "$out"
    find "$out" -xtype l -delete

    while IFS= read -r addonEntry; do
      substituteInPlace "$addonEntry" \
        --replace-fail "${addonRequireBuiltin}" "${addonRequireBuiltinPatched}"
    done < <(find "$out" -path '*node-addon-require-builtin/lib/index.js' -type f)

    substituteInPlace \
      "$out/packages/experimental/inspector/lib/index.js" \
      --replace-fail '${inspectorSpawnWorkerExecArgv}' '${inspectorSpawnWorkerExecArgvPatched}'

    substituteInPlace \
      "$out/packages/terminal/terminal-bash/lib/index.js" \
      --replace-fail '"/bin/bash"' '"${lib.getExe bashInteractive}"'

    runHook postInstall
  '';

  meta = {
    description = "Internal DeepSeek Harness build used by dsh-desktop";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
})
