{
  inputs,
  self,
  ...
}:
{

  # Entry point for host:
  flake.nixosConfigurations.kvadra-laptop = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.host-kvadra-laptop
    ];
  };

  flake.nixosModules.host-kvadra-laptop =
    { pkgs, ... }:
    {
      imports = [
        self.nixosModules.base
        self.nixosModules.general
        self.nixosModules.desktop
      ];

      # Bootloader.
      boot = {
        loader = {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
        };
      };

      networking = {
        hostName = "kvadra-laptop";
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

      environment.systemPackages = with pkgs; [
        wget
        vscode
        vim
        nano
        git
      ];

      system.stateVersion = "25.11"; # Did you read the comment?
    };
}
