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
      imports = [
        wlib.wrapperModules.niri
      ];

      options.terminal = lib.mkOption {
        type = lib.types.str;
        default = "kitty";
      };

      config.settings = {

        prefer-no-csd = _: { };

        outputs = {

          "${self.monitors.laptop.name}" = {
            mode = self.monitors.laptop.mode;
            focus-at-startup = _: { };
            scale = self.monitors.laptop.scale;

            position = _: {
              props = {
                x = self.monitors.laptop.position.x;
                y = self.monitors.laptop.position.y;
              };
            };
          };
        }
        // lib.optionalAttrs self.monitors.external.enable {
          "${self.monitors.external.name}" = {
            mode = self.monitors.external.mode;
            focus-at-startup = _: { };

            scale = self.monitors.external.scale;

            position = _: {
              props = {
                x = self.monitors.external.position.x;
                y = self.monitors.external.position.y;
              };
            };
          };
        };

        binds = {
          # ============================================================================
          # SYSTEM COMMANDS
          # ============================================================================

          # Launch the default terminal
          "Ctrl+Alt+T".spawn = config.terminal;
          "Mod+S".spawn-sh = "${noctaliaExe} ipc call launcher toggle";
          "Mod+Ctrl+S".spawn-sh = "${pkgs.grim}/bin/grim -l 0 - | ${pkgs.wl-clipboard}/bin/wl-copy";
          "Mod+Shift+E".spawn-sh = "${pkgs.wl-clipboard}/bin/wl-paste | ${pkgs.swappy}/bin/swappy -f -";
          "Mod+Shift+S".spawn-sh =
            "${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp -w 0)\" - | ${pkgs.wl-clipboard}/bin/wl-copy";

          # Show an overlay with all available keybindings (help screen)
          "Mod+Shift+Space".show-hotkey-overlay = _: { };

          # ============================================================================
          # WINDOW MANAGEMENT
          # ============================================================================

          "Mod+Q".close-window = _: { };
          "Mod+F".maximize-column = _: { };
          "Mod+G".fullscreen-window = _: { };
          "Mod+Shift+F".toggle-window-floating = _: { };
          "Mod+C".center-column = _: { };

          # ============================================================================
          # VIM-STYLE NAVIGATION (HJKL)
          # ============================================================================

          "Mod+H".focus-column-left = _: { };
          "Mod+L".focus-column-right = _: { };
          "Mod+K".focus-window-up = _: { };
          "Mod+J".focus-window-down = _: { };

          # --- Move columns and windows around ---
          "Mod+Alt+H".move-column-left = _: { };
          "Mod+Alt+L".move-column-right = _: { };
          "Mod+Alt+K".move-window-up = _: { };
          "Mod+Alt+J".move-window-down = _: { };

          # --- Resize ---
          "Mod+Ctrl+H".set-column-width = "-5%";
          "Mod+Ctrl+L".set-column-width = "+5%";
          "Mod+Ctrl+J".set-window-height = "-5%";
          "Mod+Ctrl+K".set-window-height = "+5%";

          # --- Switch between monitors and workspaces ---
          "Mod+Shift+H".focus-monitor-left = _: { };
          "Mod+Shift+L".focus-monitor-right = _: { };
          "Mod+Shift+K".focus-workspace-up = _: { };
          "Mod+Shift+J".focus-workspace-down = _: { };

          # ============================================================================
          # STANDARD NAVIGATION (ARROW KEYS)
          # Mirrors the Vim-style bindings for those who prefer arrow keys
          # ============================================================================

          # --- Focus navigation ---
          "Mod+Left".focus-column-left = _: { };
          "Mod+Right".focus-column-right = _: { };
          "Mod+Up".focus-window-up = _: { };
          "Mod+Down".focus-window-down = _: { };

          # --- Move columnsworkspaces and windows around ---
          "Mod+Alt+Left".move-column-left = _: { };
          "Mod+Alt+Right".move-column-right = _: { };
          "Mod+Alt+Up".move-window-up = _: { };
          "Mod+Alt+Down".move-window-down = _: { };

          # --- Resize ---
          "Mod+Ctrl+Left".set-column-width = "-5%";
          "Mod+Ctrl+Right".set-column-width = "+5%";
          "Mod+Ctrl+Up".set-window-height = "-5%";
          "Mod+Ctrl+Down".set-window-height = "+5%";

          # --- Switch between monitors and workspaces ---
          "Mod+Shift+Left".focus-monitor-left = _: { };
          "Mod+Shift+Right".focus-monitor-right = _: { };
          "Mod+Shift+Up".focus-workspace-up = _: { };
          "Mod+Shift+Down".focus-workspace-down = _: { };

          # ============================================================================
          # WORKSPACES
          # ============================================================================

          # --- Switch to a specific workspace ---
          # Keys 1-0 switch to workspaces w0-w9
          "Mod+1".focus-workspace = "w0";
          "Mod+2".focus-workspace = "w1";
          "Mod+3".focus-workspace = "w2";
          "Mod+4".focus-workspace = "w3";
          "Mod+5".focus-workspace = "w4";
          "Mod+6".focus-workspace = "w5";
          "Mod+7".focus-workspace = "w6";
          "Mod+8".focus-workspace = "w7";
          "Mod+9".focus-workspace = "w8";
          "Mod+0".focus-workspace = "w9"; # 0 = the 10th workspace

          # --- Move the focused column to another workspace ---
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

          # ============================================================================
          # ADDITIONAL NAVIGATION (Numpad)
          # NumLock must be active for this
          # ============================================================================
          # --- Switch to a specific workspace ---
          # Keys 1-0 switch to workspaces w0-w9
          "Mod+KP_1".focus-workspace = "w0";
          "Mod+KP_2".focus-workspace = "w1";
          "Mod+KP_3".focus-workspace = "w2";
          "Mod+KP_4".focus-workspace = "w3";
          "Mod+KP_5".focus-workspace = "w4";
          "Mod+KP_6".focus-workspace = "w5";
          "Mod+KP_7".focus-workspace = "w6";
          "Mod+KP_8".focus-workspace = "w7";
          "Mod+KP_9".focus-workspace = "w8";
          "Mod+KP_0".focus-workspace = "w9"; # 0 = the 10th workspace

          # --- Move the focused column to another workspace ---
          # The column will disappear from the current screen and appear on the target workspace
          "Mod+Shift+KP_1".move-column-to-workspace = "w0";
          "Mod+Shift+KP_2".move-column-to-workspace = "w1";
          "Mod+Shift+KP_3".move-column-to-workspace = "w2";
          "Mod+Shift+KP_4".move-column-to-workspace = "w3";
          "Mod+Shift+KP_5".move-column-to-workspace = "w4";
          "Mod+Shift+KP_6".move-column-to-workspace = "w5";
          "Mod+Shift+KP_7".move-column-to-workspace = "w6";
          "Mod+Shift+KP_8".move-column-to-workspace = "w7";
          "Mod+Shift+KP_9".move-column-to-workspace = "w8";
          "Mod+Shift+KP_0".move-column-to-workspace = "w9";

        };

        layout = {
          gaps = 5;

          focus-ring = {
            width = 2;
            active-color = "#${self.themeNoHash.base09}";
          };
        };

        workspaces =
          let
            settings = {
              layout.gaps = 5;
              open-on-output = self.monitors.external.name;
            };
          in
          {
            "w0" = settings;
            "w1" = settings;
            "w2" = settings;
            "w3" = settings;
            "w4" = settings;
            "w5" = settings;
            "w6" = settings;
            "w7" = settings;
            "w8" = settings;
            "w9" = settings;
          };

        xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

        spawn-at-startup = [
          noctaliaExe
        ];

        # spawn-sh-at-startup = [
        #   "${pkgs.swaybg}/bin/swaybg -i ${self.wallpaper} -m fill"
        # ];

      };
    };
}
