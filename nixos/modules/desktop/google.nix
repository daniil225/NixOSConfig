{
  flake.nixosModules.google = 
    { pkgs,... }:
    {
      programs.chromium = {
        enable = true;
      };
    };
}