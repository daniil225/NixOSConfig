{ lib, ... }:
{
  flake.nixosModules.gpu =
    { config, ... }:
    {

      # enable nvidia driver
      services.xserver =
        { }
        // lib.optionalAttrs config.preferences.nvidia.enable {
          videoDrivers = [ "nvidia" ];
        };

      boot =
        { }
        // lib.optionalAttrs config.preferences.nvidia.enable {
          # Load nvidia driver
          kernelParams = [ "nvidia-drm.modeset=1" ];
        };

      hardware = {
        graphics = {
          enable = true;
          enable32Bit = true;
        };
      }
      // lib.optionalAttrs config.preferences.nvidia.enable {
        nvidia = {
          open = config.preferences.nvidia.forceOpenSource;
          # driver module enablement
          modesetting.enable = true;
          powerManagement = {
            enable = true;
            finegrained = !(lib.hasInfix "RTX 10" "${config.preferences.nvidia.generation}"); # only Turing and newer (RTX 20xx+)
          };
          nvidiaSettings = true;
          package = config.boot.kernelPackages.nvidiaPackages.stable;
          prime = {
            reverseSync.enable = true;

            offload = {
              enable = true;
              enableOffloadCmd = true; # make comand nixGL/Nvidia-offload
            };
            nvidiaBusId = "${config.preferences.nvidia.busId}";
          }
          // (
            if config.preferences.cpu.vendor == "intel" then
              {
                intelBusId = "${config.preferences.cpu.iGpuBusId}";
              }
            else
              {
                amdgpuBusId = "${config.preferences.cpu.iGpuBusId}";
              }
          );
        };
      };
    };
}
