{ lib }:
import ../support/load-library.nix {
  inherit lib;
  directory = ./.;
}
