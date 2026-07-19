{ self, ... }:
{
  flake.nixosModules.devtools =
    { pkgs, ... }:
    {
      imports = [
        self.nixosModules.vscode
      ];
    };
}