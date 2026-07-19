{
  flake.nixosModules.firefox = 
    { pkgs, ...}:
    {
      environment.systemPackages = [
        pkgs.firefox
      ];
      
      programs.firefox.enable = true;
    };
}