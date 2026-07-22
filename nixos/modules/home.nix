{ lib, ... }:
let
  homeDir = ./home;
in
{
  flake.homeModules = lib.listToAttrs (
    map (path: {
      name = lib.removeSuffix ".nix" (baseNameOf (toString path));
      value = import path;
    }) (lib.filter (p: lib.hasSuffix ".nix" (toString p)) (lib.filesystem.listFilesRecursive homeDir))
  );
}
