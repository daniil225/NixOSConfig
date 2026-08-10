{ self, ... }:
{
  flake.nixosModules.desktop =
    { pkgs, config, ... }:
    let
      selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
    in
    {
      imports = [
        self.nixosModules.firefox
        self.nixosModules.telegram
        self.nixosModules.google
        self.nixosModules.vscode
      ];

      programs.niri = {
        enable = true;
        package = selfpkgs.niri;
      };

      environment.systemPackages = [
        selfpkgs.noctalia-shell
        pkgs.kitty # Терминал
        pkgs.fuzzel # Лаунчер приложений (быстрый и легкий)
        pkgs.wl-clipboard # Буфер обмена (копировать/вставлять)

        # Для работы Xwayland-satellite:
        pkgs.xwayland-satellite

        # Базовые утилиты, чтобы не было совсем грустно:
        pkgs.pcmanfm # Простой файловый менеджер
        pkgs.mako # Уведомления (опционально, но полезно)
      ];

      fonts.packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        ubuntu-sans
        cm_unicode
        corefonts
        unifont
      ];

      fonts.fontconfig.defaultFonts = {
        serif = [ "Ubuntu Sans" ];
        sansSerif = [ "Ubuntu Sans" ];
        monospace = [ "JetBrainsMono Nerd Font" ];
      };

      services.upower.enable = true;
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware = {
        enableAllFirmware = true;

        bluetooth.enable = true;
        bluetooth.powerOnBoot = true;

        graphics = {
          enable = true;
        };

        nvidia = {
          modesetting.enable = true;
          open = false;
          powerManagement.enable = false;
          nvidiaSettings = true;
          package = config.boot.kernelPackages.nvidiaPackages.stable;
          prime = {
            sync.enable = true;

            # Ваши Bus ID из lspci
            amdgpuBusId = "PCI:5:0:0";
            nvidiaBusId = "PCI:1:0:0";
          };
        };
      };

    };
}
