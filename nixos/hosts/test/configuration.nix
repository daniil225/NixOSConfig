{
  inputs,
  self,
  ...
}:
{
  # Entry point for host:
  flake.nixosConfigurations.test = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.host-test
    ];
  };

  flake.nixosModules.host-test =
    { pkgs, config, ... }:
    {

      imports = [
        self.diskoConfigurations.host-test
        self.nixosModules.base
        self.nixosModules.general
        inputs.disko.nixosModules.disko
        self.nixosModules.desktop
      ];

      preferences = {
        host.name = "test";
        network.host.name = "test";
        time.timeZone = "Asia/Novosibirsk";
        user.name = "daniil";
      };

      # Bootloader (from system config)
      boot = {
        loader = {
          grub.enable = true;
          grub.efiSupport = true;
          grub.efiInstallAsRemovable = true;
          grub.useOSProber = true;
          grub.devices = [ "nodev" ];
          #systemd-boot.enable = true;
          #efi.canTouchEfiVariables = true;
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

      # Needs to be decomposed
      environment.systemPackages = with pkgs; [
        wget
        vscode
        vim
        nano
        git
        jq
        shfmt
        gptfdisk # disk formater
        parted # partirion table update
        bc
      ];

      system.stateVersion = "25.11";
    };
}
