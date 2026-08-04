_final: prev:
let
  repository = import ./default.nix { pkgs = prev; };
  reservedNames = import ./support/reserved-names.nix;
in
builtins.removeAttrs repository reservedNames
