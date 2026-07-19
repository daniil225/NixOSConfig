{ self, ... }:
{
  flake.nixosModules.base-cli =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        wget
        nano
        vim
        git
        jq
        tree
        bc
        gcc
        killall
      ];
    };
}
