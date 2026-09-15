{
  buildGoLatestModule,
  curl,
  fetchFromGitHub,
  lib,
  runCommand,
  versionData ? builtins.fromJSON (builtins.readFile ./hashes.json),
}:
buildGoLatestModule (finalAttrs: {
  pname = "weread-kit";
  inherit (versionData) version;

  root = fetchFromGitHub {
    owner = "27Aaron";
    repo = "WeRead-Kit";
    tag = "v${finalAttrs.version}";
    inherit (versionData) hash;
  };

  # Prune to the files the build needs so doc and screenshot changes do not
  # rebuild the package. cleanSourceWith cannot be used here: it validates the
  # fetched store path at evaluation time and fails on a fresh store with
  # "path ... is not valid" because the .drv is not realised yet.
  src = runCommand "weread-kit-src" { } ''
    mkdir -p $out
    cp -r ${finalAttrs.root}/cmd ${finalAttrs.root}/internal $out/
    install -m 0644 ${finalAttrs.root}/go.mod ${finalAttrs.root}/go.sum \
      ${finalAttrs.root}/LICENSE $out/
  '';

  env.CGO_ENABLED = "0";

  vendorHash = versionData.vendorHash;

  ldflags = [
    "-s"
    "-w"
  ];

  postInstall = ''
    install -Dm644 LICENSE "$out/share/licenses/weread-kit/LICENSE"
  '';

  # The service exposes no --version flag; verify it boots and serves.
  doInstallCheck = true;
  nativeInstallCheckInputs = [ curl ];
  installCheckPhase = ''
    runHook preInstallCheck

    export WEREAD_HOST=127.0.0.1
    export WEREAD_PORT=18964
    export WEREAD_DB="$(mktemp -d)/weread.db"

    "$out/bin/weread-kit" &
    server_pid=$!
    trap 'kill "$server_pid" 2>/dev/null || true' EXIT

    for _ in $(seq 1 30); do
      if curl -fsS "http://127.0.0.1:$WEREAD_PORT/healthz" >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done
    curl -fsS "http://127.0.0.1:$WEREAD_PORT/healthz" | grep -q '"status":"ok"'
    curl -fsS "http://127.0.0.1:$WEREAD_PORT/api/version" | grep -q 'current_version'

    runHook postInstallCheck
  '';

  meta = {
    description = "WeRead account management and reading challenge automation";
    homepage = "https://github.com/27Aaron/WeRead-Kit";
    changelog = "https://github.com/27Aaron/WeRead-Kit/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "weread-kit";
    platforms = lib.platforms.unix;
  };
})
