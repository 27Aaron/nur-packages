{ pkgs }:
let
  loadLibrary = import ../support/load-library.nix;
  library = loadLibrary {
    inherit (pkgs) lib;
    directory = ./fixtures/library/success;
  };
  evaluationFails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
in
assert
  library == {
    alpha = 1;
    nested = {
      left = 2;
      right = 3;
    };
  };
assert evaluationFails (loadLibrary {
  inherit (pkgs) lib;
  directory = ./fixtures/library/duplicate;
});
pkgs.runCommandLocal "repo-library" { } ''
  touch "$out"
''
