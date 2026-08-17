{
  flake.diskoConfigurations.host-hp-omen-gaming-16-am0xxx = {
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          device = "/dev/disk/by-id/nvme-eui.8ce38e1003f2fc06";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                type = "EF00";
                size = "1G";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
              };
              root = {
                size = "100%";
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
              swap = {
                size = "32G";
                content = {
                  type = "swap";
                };
              };
            };
          };
        };
      };
    };
  };
}
