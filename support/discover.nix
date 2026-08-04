{
  directory,
  reservedNames ? [ ],
  transform ? (_name: path: path),
}:
let
  entries = builtins.readDir directory;
  hasNixSuffix = name: builtins.match ".*\\.nix" name != null;
  entryPath = name: directory + "/${name}";
  defaultPath = name: entryPath name + "/default.nix";
  isReadableFile = path: builtins.seq (builtins.readFile path) true;

  isDiscoverable =
    name: type:
    name != "default.nix"
    && (
      (type == "regular" && hasNixSuffix name)
      || (type == "directory" && builtins.pathExists (defaultPath name))
      || (
        type == "symlink"
        && (
          (hasNixSuffix name && isReadableFile (entryPath name))
          || (builtins.pathExists (defaultPath name) && isReadableFile (defaultPath name))
        )
      )
    );

  toAttribute =
    name:
    let
      length = builtins.stringLength name;
      attribute = if hasNixSuffix name then builtins.substring 0 (length - 4) name else name;
    in
    {
      name = attribute;
      value = transform attribute (entryPath name);
    };
  discovered = map toAttribute (
    builtins.filter (name: isDiscoverable name entries.${name}) (builtins.attrNames entries)
  );
in
builtins.foldl' (
  result: entry:
  if builtins.elem entry.name reservedNames then
    throw "Discovered reserved attribute '${entry.name}' in ${toString directory}"
  else if builtins.hasAttr entry.name result then
    throw "Duplicate discovered attribute '${entry.name}' in ${toString directory}"
  else
    result // { ${entry.name} = entry.value; }
) { } discovered
