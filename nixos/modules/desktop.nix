{ self, ... }:
{
  flake.nixosModules.desktop =
    { pkgs, ... }:
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
      hardware = {
        enableAllFirmware = true;

        bluetooth.enable = true;
        bluetooth.powerOnBoot = true;

        opengl = {
          enable = true;
          driSupport32Bit = true;
        };
      };

    };
}
