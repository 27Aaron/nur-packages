{ pkgs }:
let
  discover = import ../support/discover.nix;
  names = discover {
    directory = ./fixtures/discover/success;
    transform = name: _path: name;
  };
  evaluationFails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
in
assert
  builtins.attrNames names == [
    "directory-link"
    "file-link"
    "name-default"
    "regular"
  ];
assert names.regular == "regular";
assert evaluationFails (discover {
  directory = ./fixtures/discover/duplicate;
});
assert evaluationFails (discover {
  directory = ./fixtures/discover/reserved;
  reservedNames = [ "lib" ];
});
pkgs.runCommandLocal "repo-discovery" { } ''
  touch "$out"
''
