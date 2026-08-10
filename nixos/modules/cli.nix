{ self, ... }:
{
  flake.nixosModules.cli =
    { ... }:
    {
      imports = [
        self.nixosModules.base-cli
        self.nixosModules.disk-cli
        self.nixosModules.diagnostic-cli
      ];
    };
}
