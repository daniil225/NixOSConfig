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
    };
  };
}
