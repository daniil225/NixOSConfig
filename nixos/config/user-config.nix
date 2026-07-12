{ lib, ... }:
{
  flake.nixosModules.base = { lib, ... }: {
    options.preferences = {
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
