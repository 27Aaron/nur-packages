# This file provides all the buildable and cacheable packages and
# package outputs in your package set. These are what gets built by CI,
# so if you correctly mark packages as
#
# - broken (using `meta.broken`),
# - unfree (using `meta.license.free`), and
# - locally built (using `preferLocalBuild`)
#
# then your CI will be able to build and cache only those packages for
# which this is possible.
{
  pkgs ? import <nixpkgs> { },
}:
let
  inherit (builtins)
    attrValues
    concatLists
    filter
    isAttrs
    map
    ;
  reservedNames = import ./support/reserved-names.nix;
  repository = builtins.removeAttrs (import ./default.nix { inherit pkgs; }) reservedNames;

  isDerivation = package: isAttrs package && package.type or null == "derivation";
  isBuildable =
    package:
    let
      licenseFromMeta = package.meta.license or [ ];
      licenseList = if builtins.isList licenseFromMeta then licenseFromMeta else [ licenseFromMeta ];
    in
    !(package.meta.broken or false) && builtins.all (license: license.free or true) licenseList;
  isCacheable = package: !(package.preferLocalBuild or false);
  shouldRecurse = package: isAttrs package && package.recurseForDerivations or false;

  concatMap = builtins.concatMap or (f: xs: concatLists (map f xs));

  flattenPackages =
    packages:
    let
      flatten =
        package:
        if shouldRecurse package then
          flattenPackages package
        else if isDerivation package then
          [ package ]
        else
          [ ];
    in
    concatMap flatten (attrValues packages);
  outputsOf = package: map (output: package.${output}) package.outputs;
in
rec {
  buildPkgs = filter isBuildable (flattenPackages repository);
  cachePkgs = filter isCacheable buildPkgs;
  buildOutputs = concatMap outputsOf buildPkgs;
  cacheOutputs = concatMap outputsOf cachePkgs;
}
