{ lib, ... }:
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
    };
  };
}
