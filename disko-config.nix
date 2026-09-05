{
  disko = {
    enableConfig = true;
    devices = {
      disk = {
        # This can be expanded to multiple physical disks.
        ssd1 = {
          type = "disk";
          # Set the correct drive ID.
          # Check the id using `lsblk -o +ID`
          # Double check the id by validating `ls -l /dev/disk/by-id/`
          device = "/dev/disk/by-id/nvme-eui.002538a851400a12";
          content = {
            # Partition table to enable UEFI boot.
            type = "gpt";
            partitions = {
              # This is teh BOOT partition
              ESP = {
                priority = 1;
                # This is the boot partition. Unencrypted to boot before
                # decryption of the LUKS partition.
                name = "ESP";
                label = "boot";
                start = "1M";
                end = "4097M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  # Enforces that the root user cannot be accessed by any other user
                  # Practically umask is a whitelistiing set-up
                  mountOptions = [ "umask=0077" ];
                };
              };
              # Install partition, luks is the encryption tehcnology
              # Its the root drive encrypted with luks :)
              luks-root = {
                priority = 2;
                name = "luks-root";
                label = "luks-root";
                # This next bit is the space at the end of the drive for the
                # SWAP partition.
                # How much SWAP to allocate? https://itsfoss.com/swap-size/
                # For this machine, 64GB of ram, 8GB of SWAP.
                end = "-8G";
                content = {
                  type = "luks";
                  name = "crypted-root";
                  extraOpenArgs = [ ];
                  settings = {
                    # if you want to use the key for interactive login be sure
                    # there is no trailing newline, for example use
                    # `echo -n "password" > /tmp/secret.key`
                    # Comment this next line to input a passphrase when prompted
                    # keyFile = "/tmp/secret.key";
                    allowDiscards = true;
                  };
                  # Add this line for additional key files.
                  # additionalKeyFiles = [ "/tmp/additionalSecret.key" ];
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/";
                  };
                };
              };
              encryptedSwap = {
                priority = 3;
                name = "crypted-swap";
                label = "crypted-swap";
                # Take the end of the drive for SWAP.
                size = "100%";
                content = {
                  type = "swap";
                  # This re-encrypts the swap partition every boot.
                  randomEncryption = true;
                  # Prefer to encrypt as long as we have space for it.
                  priority = 100;
                  discardPolicy = "both";
                  # Hibernation on an encrypted swap partition doesn't
                  # work (like this).
                  resumeDevice = false;
                };
              };
            };
          };
        };
        ssd2 = {
          type = "disk";
          # Set the correct drive ID.
          # Check the id using `lsblk -o +ID`
          # Double check the id by validating `ls -l /dev/disk/by-id/`
          device = "/dev/disk/by-id/nvme-WD_BLACK_SN7100_2TB_255231806087";
          content = {
            # Partition table to enable UEFI boot.
            type = "gpt";
            partitions = {
              luks = {
                priority = 4;
                name = "luks-ssd";
                label = "luks-ssd";
                # This next bit is the space at the end of the drive for the
                # SWAP partition.
                # How much SWAP to allocate? https://itsfoss.com/swap-size/
                # For this machine, 64GB of ram, 8GB of SWAP.
                size = "100%";
                content = {
                  type = "luks";
                  name = "crypted-ssd";
                  extraOpenArgs = [ ];
                  settings = {
                    # if you want to use the key for interactive login be sure
                    # there is no trailing newline, for example use
                    # `echo -n "password" > /tmp/secret.key`
                    # Comment this next line to input a passphrase when prompted
                    # keyFile = "/tmp/secret.key";
                    allowDiscards = true;
                  };
                  # Add this line for additional key files.
                  # additionalKeyFiles = [ "/tmp/additionalSecret.key" ];
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/mnt/ssd";
                  };
                };
              };
            };
          };
        };
        hdd1 = {
          type = "disk";
          # Set the correct drive ID.
          device = "/dev/disk/by-id/wwn-0x5000c50114415644";
          content = {
            type = "gpt";
            partitions = {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "zhdd";
                };
              };
            };
          };
        };
        hdd2 = {
          type = "disk";
          # Set the correct drive ID.
          device = "/dev/disk/by-id/wwn-0x5000c50113ff1107";
          content = {
            type = "gpt";
            partitions = {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "zhdd";
                };
              };
            };
          };
        };
        hdd3 = {
          type = "disk";
          # Set the correct drive ID.
          device = "/dev/disk/by-id/wwn-0x5000c50113fe629c";
          content = {
            type = "gpt";
            partitions = {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "zhdd";
                };
              };
            };
          };
        };
        hdd4 = {
          type = "disk";
          # Set the correct drive ID.
          device = "/dev/disk/by-id/wwn-0x5000c5011440eea6";
          content = {
            type = "gpt";
            partitions = {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "zhdd";
                };
              };
            };
          };
        };
        hdd5 = {
          type = "disk";
          # Set the correct drive ID.
          device = "/dev/disk/by-id/wwn-0x5000c501143f205d";
          content = {
            type = "gpt";
            partitions = {
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "zhdd";
                };
              };
            };
          };
        };
      };
      zpool = {
        # This is the pool the disks are added to, note the pool spec on the disk config
        zhdd = {
          type = "zpool";
          # RAIDZ == RAID 5
          mode = "raidz";
          # Workaround: cannot import 'zhdd': I/O error in disko tests
          options = {
            cachefile = "none";
          };
          rootFsOptions = {
            canmount = "off";
            mountpoint = "none";
            compression = "zstd";
            "com.sun:auto-snapshot" = "true";
          };
          datasets = {
            zdata = {
              type = "zfs_fs";
              options = {
                encryption = "aes-256-gcm";
                keyformat = "passphrase";
                #keylocation = "file:///var/lib/zfs/secret.key";
              };
              mountpoint = "/mnt/zdata";
            };
          };
        };
      };
    };
  };
}
