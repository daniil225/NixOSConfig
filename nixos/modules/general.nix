{ self, ... }:
{
  flake.nixosModules.general =
    {
      pkgs,
      config,
      ...
    }:
    {
      imports = [
        self.nixosModules.nix
      ];

      # Define a user account. Don't forget to set a password with ‘passwd’.
      users.users.${config.preferences.user.name} = {
        isNormalUser = true;
        description = "${config.preferences.user.name}'s account";
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
        # Set custop console interpritator that determine in custom 
        # packages in environment variabel 
        #shell = self.packages.${pkgs.system}.environment;
      };
    };
}
