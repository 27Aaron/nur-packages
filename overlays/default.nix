let
  discover = import ../support/discover.nix;
in
discover {
  directory = ./.;
  reservedNames = [ "default" ];
  transform = _name: path: import path;
}
// {
  default = import ../overlay.nix;
}
