{
  flake.diskoConfigurations.host-test = {
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          device = "/dev/disk/by-id/usb-Lexar_USB_Flash_Drive_7950061201354521-0:0";
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
              root2 = {
                size = "11.9G";
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
              swap = {
                size = "4G";
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
