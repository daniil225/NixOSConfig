{ self, ... }:
{
  flake.nixosModules.desktop =
    { pkgs, ... }:
    let
      selfpkgs = self.packages."pkgs.system";
    in
    {
      imports = [
        self.nixosModules.firefox
        self.nixosModules.telegram
        self.nixosModules.google
      ];
    };
}
