let
  discovered = import ../../support/discover.nix {
    directory = ../fixtures/discover/broken;
  };
in
builtins.deepSeq discovered true
