{ pkgs, ... }:
{

  home.packages = with pkgs; [
    nil # LSP для Nix (быстрый)
    nixd # LSP для Nix (умный, понимает сложные конструкции)
    nixfmt
    statix # Линтер
    alejandra # Альтернативный форматтер
    manix # Поиск по документации NixOS
    nix-inspect # Инспекция дериваций
  ];

  # Direnv для автоматической загрузки окружений
  programs.direnv = {
    enable = true;
    silent = false;
    nix-direnv.enable = true;
  };
}
