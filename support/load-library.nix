{
  directory,
  lib,
}:
let
  files = import ./discover.nix { inherit directory; };
  mergeAttrs =
    path: left: right:
    lib.foldl' (
      result: name:
      let
        attributePath = path ++ [ name ];
      in
      if !builtins.hasAttr name result then
        result // { ${name} = right.${name}; }
      else if builtins.isAttrs result.${name} && builtins.isAttrs right.${name} then
        result // { ${name} = mergeAttrs attributePath result.${name} right.${name}; }
      else
        throw "Duplicate library attribute '${lib.concatStringsSep "." attributePath}'"
    ) left (builtins.attrNames right);

  load =
    name: path:
    let
      value = import path { inherit lib; };
    in
    if builtins.isAttrs value then
      value
    else
      throw "Library module '${name}' must return an attribute set";
in
lib.foldl' (mergeAttrs [ ]) { } (lib.mapAttrsToList load files)
