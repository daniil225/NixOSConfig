{
  flake.nixosModules.google = 
    { pkgs,... }:
    {

      environment.systemPackages = [
        pkgs.google-chrome
      ];

      programs.chromium = {
        enable = true;
      };
    };
}