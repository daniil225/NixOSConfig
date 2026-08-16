let
  monitors = {
    external = {
      enable = true;
      mode = "2560x1440@60.000000";
      name = "HDMI-A-1";
      scale = 1.0;
      position = {
        x = 0;
        y = 0;
      };
    };

    laptop = {
      mode = "2560x1600@240.00";
      name = "eDP-1";
      scale = 1.0;
      position = {
        x = 2560;
        y = 0;
      };
    };
  };
in
{
  flake = { inherit monitors; };
}
