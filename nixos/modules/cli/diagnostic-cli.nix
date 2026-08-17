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
        htop
        btop
        nvtopPackages.full
      ];

      # if CPU vendor == AMD add lact
    };
}
