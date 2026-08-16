{
  inputs,
  self,
  ...
}:
{
  # Entry point for host:
  flake.nixosConfigurations.hp-omen = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.host-hp-omen
    ];
  };

  flake.nixosModules.host-hp-omen =
    { pkgs, config, ... }:
    {

      imports = [
        self.nixosModules.base
        self.nixosModules.general
        self.nixosModules.desktop
        self.nixosModules.devtools
        self.nixosModules.cli
        self.diskoConfigurations.host-hp-omen

        inputs.disko.nixosModules.disko
        inputs.home-manager.nixosModules.home-manager
      ];

      preferences = {
        host.name = "hp-omen";
        network.host.name = "hp-omen";
        user.name = "daniil";
        flake-base-dir = "/home/daniil/NixOSConfig";
      };

      # Настройки самого модуля home-manager
      home-manager = {
        useUserPackages = true; # пакеты HM ставятся в профиль пользователя, а не системы
        useGlobalPkgs = true; # использовать pkgs из NixOS (экономит место)
        backupFileExtension = "backup"; # что делать с конфликтующими конфигами
        extraSpecialArgs = {
          inherit inputs self;
          userName = config.preferences.user.name;
          flakeBaseDir = config.preferences.flake-base-dir;
          flakeNixosConfigurations = config.preferences.host.name;
        };

        users.${config.preferences.user.name} = {
          imports = [
            self.homeModules.base
            self.homeModules.nix-tooling
            self.homeModules.vscode
          ];
        };
      };

      # Bootloader. from system config
      boot = {
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
      };

      networking = {
        hostName = config.preferences.network.host.name;
        networkmanager.enable = true;
      };

      services = {
        # X11 windowing system.
        xserver = {
          enable = true;
          # Enable the GNOME Desktop Environment.
          displayManager.gdm.enable = true;
          desktopManager.gnome.enable = true;
          # Configure keymap in X11
          xkb = {
            layout = "us,ru";
            variant = "";
            options = "grp:win_space_toggle";
          };
        };

        # Enable CUPS to print documents.
        printing.enable = true;

        # Enable sound with pipewire.
        pulseaudio.enable = false;
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };
      };

      security = {
        rtkit.enable = true;
      };

      system.stateVersion = "25.11";
    };
}
