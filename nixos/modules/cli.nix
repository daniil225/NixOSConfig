{ self, ... }:
{
  flake.nixosModules.cli =
    { pkgs, ... }:
    {
      imports = [
        self.nixosModules.base-cli
        self.nixosModules.disk-cli
      ];
    };
}
