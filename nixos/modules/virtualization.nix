{ self, ... }:
{
  flake.nixosModules.virtualisation = { ... }: {
    imports = [
      self.nixosModules.docker
    ];
  };
}
