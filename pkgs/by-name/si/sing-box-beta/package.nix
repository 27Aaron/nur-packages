{
  fetchFromGitHub,
  sing-box,
  versionCheckHook,
  versionData ? builtins.fromJSON (builtins.readFile ./hashes.json),
}:
sing-box.overrideAttrs (
  _finalAttrs: previousAttrs: {
    pname = "sing-box-beta";
    inherit (versionData) version vendorHash;

    src = fetchFromGitHub {
      owner = "SagerNet";
      repo = "sing-box";
      tag = "v${versionData.version}";
      inherit (versionData) hash;
    };

    doInstallCheck = true;
    nativeInstallCheckInputs = (previousAttrs.nativeInstallCheckInputs or [ ]) ++ [ versionCheckHook ];
    versionCheckProgramArg = "version";

    passthru = builtins.removeAttrs (previousAttrs.passthru or { }) [ "tests" ];

    meta = (previousAttrs.meta or { }) // {
      changelog = "https://github.com/SagerNet/sing-box/releases/tag/v${versionData.version}";
    };
  }
)
