{ ... }:
{
  flake.nixosModules.base = { lib, ... }: {
    options.preferences = {
      host.name = lib.mkOption {
        type = lib.types.str;
        default = throw "host.name must be explicitly set in host configuration";
        description = "Host name for this machine.";
      };

      network.host.name = lib.mkOption {
        type = lib.types.str;
        default = throw "network.host.name must be explicitly set in host configuration";
        description = "Network name for this machine.";
      };

      flake-base-dir = lib.mkOption {
        type = lib.types.str;
        default = throw "flake-base-dir must be explicetly set in host configuration";
        description = "Base dir where NixOS configuration located in the system";
      };

      user.name = lib.mkOption {
        type = lib.types.str;
        default = throw "user.name must be explicitly set in host configuration";
        description = "User name for this machine.";
      };

      time.timeZone = lib.mkOption {
        type = lib.types.str;
        default = "Asia/Novosibirsk";
        description = "Time zone for this machine.";
      };

      cpu.vendor = lib.mkOption {
        type = lib.types.enum [
          "intel"
          "amd"
        ];
        default = throw "cpu.vendor must be explicitly set in host configuration";
        description = "Vendor of integrated GPU (affects BusID attribute name)";
      };

      cpu.iGpuBusId = lib.mkOption {
        type = lib.types.str;
        default = throw "cpu.iGpuBusId must be explicitly set in host configuration";
        description = "PCI Bus ID of integrated GPU. Run: lspci | grep -i vga";
      };

      nvidia.enable = lib.mkEnableOption "Nvidia dGPU support with PRIME offload";

      nvidia.busId = lib.mkOption {
        type = lib.types.str;
        default = throw "nvidia.busId must be explicitly set in host configuration";
        description = "PCI Bus ID of discrete Nvidia GPU. Run: lspci | grep -i vga";
      };

      nvidia.generation = lib.mkOption {
        type = lib.types.str;
        default = throw "nvidia.generation must be explicitly set in host configuration";
        description = ''
          GPU generation for open driver selection.
          - older (GTX 10xx and below): force proprietary driver
          - turing+ (RTX 20xx/30xx/40xx/50xx): can use open driver
          Note: RTX 5070 is Blackwell. Open driver is recommended.
        '';
      };

      nvidia.forceOpenSource = lib.mkOption {
        type = lib.types.bool;
        default = throw "nvidia.forceOpenSource must be explicitly set in host configuration";
        description = "Force proprietary driver even if generation supports open";
      };

    };
  };
}
