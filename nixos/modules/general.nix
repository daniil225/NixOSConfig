{self,...}:
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
        initialPassword = "0000";
        # Set custop console interpritator that determine in custom 
        # packages in environment variabel 
        #shell = self.packages.${pkgs.system}.environment;
      };

      # Set your time zone.
      time = {
        timeZone = config.preferences.time.timeZone;
      };
      # Select internationalisation properties.
      i18n = {
        defaultLocale = "en_US.UTF-8";
        extraLocaleSettings = {
          LC_ADDRESS = "ru_RU.UTF-8";
          LC_IDENTIFICATION = "ru_RU.UTF-8";
          LC_MEASUREMENT = "ru_RU.UTF-8";
          LC_MONETARY = "ru_RU.UTF-8";
          LC_NAME = "ru_RU.UTF-8";
          LC_NUMERIC = "ru_RU.UTF-8";
          LC_PAPER = "ru_RU.UTF-8";
          LC_TELEPHONE = "ru_RU.UTF-8";
          LC_TIME = "ru_RU.UTF-8";
        };
    };
  };
}