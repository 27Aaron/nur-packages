{
  callPackage,
  withBun ? true,
  # The same source as the GUI's, so it shares the one hashes file.
  versionData ? builtins.fromJSON (builtins.readFile ../magpie/hashes.json),
}:
# The same program built for the terminal: `gui = false` adds the `nogui`
# tag and drops cgo, the GTK build inputs and the desktop files.
callPackage ../magpie/package.nix {
  inherit withBun versionData;
  gui = false;
}
