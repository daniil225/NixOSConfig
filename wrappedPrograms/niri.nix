{
  self,
  lib,
  ...
}:
{
  flake.wrappers.niri =
    {
      wlib,
      pkgs,
      config,
      ...
    }:
    let
      noctaliaExe = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.noctalia-shell;
    in
    {
      imports = [ wlib.wrapperModules.niri ];

      config.settings = {

        prefer-no-csd = _: { };

        inputs = {
          keyboard = { };
        };

        mouse = { };

        binds = {
          "Mod+Q".close-window = _: { };
          "Mod+F".maximize-column = _: { };
          "Mod+G".fullscreen-window = _: { };
          "Mod+Shift+F".toggle-window-floating = _: { };
          "Mod+C".center-column = _: { };

          "Mod+H".focus-column-left = _: { };
          "Mod+L".focus-column-right = _: { };
          "Mod+K".focus-window-up = _: { };
          "Mod+J".focus-window-down = _: { };

          "Mod+Left".focus-column-left = _: { };
          "Mod+Right".focus-column-right = _: { };
          "Mod+Up".focus-window-up = _: { };
          "Mod+Down".focus-window-down = _: { };

          "Mod+Alt+H".move-column-left = _: { };
          "Mod+Alt+L".move-column-right = _: { };
          "Mod+Alt+K".move-window-up = _: { };
          "Mod+Alt+J".move-window-down = _: { };

          "Mod+1".focus-workspace = "w0";
          "Mod+2".focus-workspace = "w1";
          "Mod+3".focus-workspace = "w2";
          "Mod+4".focus-workspace = "w3";
          "Mod+5".focus-workspace = "w4";
          "Mod+6".focus-workspace = "w5";
          "Mod+7".focus-workspace = "w6";
          "Mod+8".focus-workspace = "w7";
          "Mod+9".focus-workspace = "w8";
          "Mod+0".focus-workspace = "w9";

          "Mod+Shift+1".move-column-to-workspace = "w0";
          "Mod+Shift+2".move-column-to-workspace = "w1";
          "Mod+Shift+3".move-column-to-workspace = "w2";
          "Mod+Shift+4".move-column-to-workspace = "w3";
          "Mod+Shift+5".move-column-to-workspace = "w4";
          "Mod+Shift+6".move-column-to-workspace = "w5";
          "Mod+Shift+7".move-column-to-workspace = "w6";
          "Mod+Shift+8".move-column-to-workspace = "w7";
          "Mod+Shift+9".move-column-to-workspace = "w8";
          "Mod+Shift+0".move-column-to-workspace = "w9";

          "Mod+WheelScrollDown".focus-column-left = _: { };
          "Mod+WheelScrollUp".focus-column-right = _: { };
          "Mod+Ctrl+WheelScrollDown".focus-workspace-down = _: { };
          "Mod+Ctrl+WheelScrollUp".focus-workspace-up = _: { };
        };

        layout = { };
        workspaces = { };
        xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

        spawn-at-startup = [
          noctaliaExe
        ];
      };
    };
}
