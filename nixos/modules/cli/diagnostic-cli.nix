{ ... }:
{
  flake.nixosModules.diagnostic-cli =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        wlr-randr
        pciutils
        mesa-demos
        vulkan-tools
      ];
    };
}
