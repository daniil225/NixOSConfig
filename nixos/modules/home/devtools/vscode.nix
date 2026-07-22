{
  pkgs,
  flakeBaseDir,
  flakeNixosConfigurations,
  ...
}:
{

  programs.vscode = {
    enable = true;
    mutableExtensionsDir = false;

    profiles = {
      "NixOSConfig" = {

        extensions = with pkgs.vscode-extensions; [
          jnoortheen.nix-ide
        ];

        userSettings = {
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "nixd";
          "nix.env.enable" = false;

          "[nix]" = {
            "editor.defaultFormatter" = "jnoortheen.nix-ide";
            "editor.formatOnSave" = true;
          };

          "files.associations" = {
            "*.nix" = "nix";
          };

          "nix.serverSettings" = {
            "nixd" = {
              "nixpkgs" = {
                "expr" = "import (builtins.getFlake \"${flakeBaseDir}\").inputs.nixpkgs { }";
              };
              "formatting" = {
                "command" = [ "nixfmt" ];
              };
              "options" = {
                "nixos" = {
                  "expr" =
                    "(builtins.getFlake \"${flakeBaseDir}\").nixosConfigurations.${flakeNixosConfigurations}.options";
                };
                "home-manager" = {
                  "expr" =
                    "(builtins.getFlake (builtins.toString \"${flakeBaseDir}\")).nixosConfigurations.${flakeNixosConfigurations}.options.home-manager.users.type.getSubOptions []";
                };
              };
            };
          };
        };
      };
    };
  };
}
