{ self, ... }:
{
  flake.nixosModules.desktop =
    { pkgs, ... }:
    let
      selfpkgs = self.packages."pkgs.system";
    in
    {
      imports = [
        self.nixosModules.firefox
        self.nixosModules.telegram
      ];

      # Set your time zone.
      time = {
        timeZone = "Asia/Novosibirsk";
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
