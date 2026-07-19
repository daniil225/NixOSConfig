{ ... }:
{
  flake.homeModules.base =
    { pkgs, userName, ... }:
    {

      programs.home-manager.enable = true;
      home.username = userName;
      home.homeDirectory = "/home/${userName}";
      home.stateVersion = "25.11";

      # Здесь всё, что раньше было в homeModules.user-daniil:
      home.packages = with pkgs; [
        # например: htop btop fd ripgrep
        btop
      ];
    };
}
