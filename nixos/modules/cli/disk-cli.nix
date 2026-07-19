{self,...}:
{
  flake.nixosModules.disk-cli = 
    {pkgs,...}:
    {
      environment.systemPackages = with pkgs; [
        gptfdisk # disk formater
        parted   # partirion table update
      ];
    };
}