{
  inputs,
  self,
  ...
}:
{
  # Entry point for host:
  flake.nixosConfigurations.asus-tufgaming-fx705 = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.host-asus-tufgaming-fx705
    ];
  };

  flake.nixosModules.host-asus-tufgaming-fx705 =
    { pkgs, config, ... }:
    {

      imports = [
        self.nixosModules.base
        self.nixosModules.general
        self.nixosModules.desktop
      ];

      preferences = {
        user.name = "daniil";
        host.name = "asus-tufgaming-fx705";
        network.host.name = "daniil";
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
        #X11 windowing system.
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

      # Nead to be decompose
      environment.systemPackages = with pkgs; [
        wget
        vscode
        vim
        nano
        git
        dialog # for interactive menu in console 
        google-chrome
        jq
        gcc
        shfmt
        gptfdisk # disk formater
        parted # partirion table update
        bc
      ];

      system.stateVersion = "25.11";
    };
}
