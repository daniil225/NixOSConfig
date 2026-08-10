{ ... }:
{
  flake.nixosModules.dev-cli =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        gcc
      ];
    };
}
