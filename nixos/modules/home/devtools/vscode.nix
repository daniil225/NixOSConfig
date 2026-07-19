{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;

    extensions = with pkgs.vscode-extensions; [
      jnoortheen.nix-ide
    ];

    userSettings = {
      # Включаем Language Server
      "nix.enableLanguageServer" = true;
      # Используем nixd (умнее, понимает ваш importTree)
      "nix.serverPath" = "nil";

      # Форматирование через nixfmt
      "nix.serverSettings" = {
        "nil" = {
          "formatting" = {
            "command" = [ "nixfmt" ];
          };
        };
      };

      "nix.env.enable" = false;
      # Форматирование при сохранении
      "[nix]" = {
        "editor.defaultFormatter" = "jnoortheen.nix-ide";
        "editor.formatOnSave" = true;
      };

      # Ассоциации файлов
      "files.associations" = {
        "*.nix" = "nix";
      };
    };
  };
}
