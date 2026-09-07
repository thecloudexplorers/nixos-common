# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  customHostName,
  inputs,
  lib,
  pkgs,
  stateVersion,
  ...
}:

{
  imports = [
    # Import Disko for local use.
    inputs.disko.nixosModules.disko
    # Import home-manager's NixOS module.
    inputs.home-manager.nixosModules.default
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./disko-config.nix
  ];

  ###################################
  # This is all ZFS specific stuff! #
  ###################################
  boot.kernelPackages =
    let
      zfsCompatibleKernelPackages = lib.filterAttrs (
        name: kernelPackages:
        (builtins.match "linux_[0-9]+_[0-9]+" name) != null
        && (builtins.tryEval kernelPackages).success
        && (!kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken)
      ) pkgs.linuxKernel.packages;
      latestKernelPackage = lib.last (
        lib.sort (a: b: (lib.versionOlder a.kernel.version b.kernel.version)) (
          builtins.attrValues zfsCompatibleKernelPackages
        )
      );
    in
    lib.mkForce latestKernelPackage;
  boot.zfs = {
    # Since we will be encrypting the ZFS filesystem, we need to ensure that
    # the ZFS kernel module is built with support for encryption. Hibernation
    # is not supported on encrypted ZFS filesystems, so we disable it.
    allowHibernation = false;
  };
  boot.initrd.availableKernelModules = [
    "ahci"
    "nvidia"
    "nvme"
    "sd_mod"
    "usb_storage"
    "usbhid"
    "xhci_pci"
    "zfs"
  ];
  boot.kernelModules = [
    "amdgpu"
    "k10temp"
    "kvm-amd"
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];
  boot.supportedFilesystems = [
    "ext4"
    "luks"
    "vfat"
    "zfs"
    "zfs_member"
  ];
  # nvidia-drm.fbdev=1 is required for Blackwell (RTX 5060 Ti) framebuffer on Wayland.
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
  ];
  boot.zfs.forceImportRoot = false;
  boot.zfs.unsafeAllowHibernation = false;
  # ZFS will also mount the ZFS partitions. This will lead to conflicts.
  systemd.services.zfs-mount.enable = false;
  services.zfs.autoScrub.enable = true;
  ##############################
  # End of ZFS specific stuff! #
  ##############################

  # This is the basic bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  hardware = {
    graphics.enable = true;
    nvidia = {
      # Whether to enable the open source NVIDIA kernel module.
      open = true;
      # Whether to enable kernel modesetting when using the NVIDIA
      # proprietary driver.
      modesetting.enable = true;
      nvidiaSettings = true;
      # Whether to enable nvidia-persistenced a update for NVIDIA
      # GPU headless mode.
      nvidiaPersistenced = false;
      powerManagement = {
        # Whether to enable experimental power management through systemd.
        enable = true;
        # Whether to enable experimental power management of PRIME offload.
        finegrained = false;
      };
      # Whether to enable dynamic Boost balances power between the CPU
      # and the GPU for improved performance on supported laptops using
      # the nvidia-powerd daemon.
      dynamicBoost.enable = false;
      # The NVIDIA driver package to use.
      # https://www.nvidia.com/en-us/drivers/unix/
      # https://github.com/NixOS/nixpkgs/pulls?q=nvidiaPackages
      # config.boot.kernelPackages.nvidiaPackages.stable; # Same as production
      # config.boot.kernelPackages.nvidiaPackages.production; # Latest production driver
      # config.boot.kernelPackages.nvidiaPackages.beta;   # Latest beta driver
      # config.boot.kernelPackages.nvidiaPackages.latest; # Same as production
      # config.boot.kernelPackages.nvidiaPackages.vulkan_beta;
      # config.boot.kernelPackages.nvidiaPackages.legacy_535; # Older versions
      # config.boot.kernelPackages.nvidiaPackages.legacy_470;
      #package = config.boot.kernelPackages.nvidiaPackages.latest;
      # 610.43.03 fails to build against Linux 7.2 (missing strncpy/string.h,
      # fixed upstream in 610.57.04): https://github.com/NixOS/nixpkgs/issues/554125
      package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "610.57.04";
        sha256_64bit = "sha256-suk1xmuDuwDAyFe8jg7g/VLekoa0DJzB7sKafOfrEW0=";
        sha256_aarch64 = "sha256-QCefrMBCmpOwuOyXv1k5Gj0iB2CYlPgnG3JToUw/j54=";
        openSha256 = "sha256-rQHOOOY4KL92Ww3KDwh+j4eGU7oNAH8LutZC5wmFnPo=";
        settingsSha256 = "sha256-ZEMo8I8Zc2Tq6RVDNYpAH+f094dUaZiBqO+5f6lIjRI=";
        persistencedSha256 = "sha256-aXmD2VY1RLlgAnlHhOUMWzvMyhI6JTClcFLm4imF/mA=";
      };
      # Whether to enable Whether video acceleration (VA-API) should
      # be enabled.
      videoAcceleration = false;
      prime = {
        # Whether to enable render offload support using the NVIDIA
        # proprietary driver via PRIME.
        offload.enable = false;
        # Needs proprietary NVIDIA driver enabled.
        # Needs videoDrivers to only have nvidia and nothing else.
        sync.enable = false;
        allowExternalGpu = false;
        # list devices using: `lspci -k -d ::03xx`
        # 3c:00.0 VGA compatible controller: NVIDIA Corporation GB206 [GeForce RTX 5060 Ti] (rev a1)
        #nvidiaBusId = "PCI:60@0:0:0";
      };
    };
  };

  hardware = {
    enableAllHardware = true;
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
  };
  services.hardware.bolt.enable = true;
  systemd.packages = with pkgs; [ lact ];

  # Generate hostId by machine: `head -c 8 /etc/machine-id`
  # Generate hostId at random: `head -c4 /dev/urandom | od -A none -t x4`
  networking.hostId = "8bda2338";
  networking.hostName = customHostName;
  networking = {
    enableIPv6 = true;
    resolvconf = {
      enable = true;
      dnsExtensionMechanism = true;
      dnsSingleRequest = false;
      useLocalResolver = false;
    };
    useDHCP = true;
    firewall.enable = true;
  };
  systemd.services.NetworkManager-wait-online.enable = false;
  systemd.targets = {
    # Disable automatic sleep/suspend/hybrid for this computer,
    # which should by default be 'always on'. It should only sleep if
    # manually put to sleep or off.
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
  networking.networkmanager.wifi = {
    backend = "iwd";
    powersave = false;
  };

  services = {
    desktopManager.plasma6.enable = true;
    displayManager = {
      autoLogin.enable = false;
      defaultSession = "plasma";
      plasma-login-manager = {
        enable = true;
        settings = {
          Users = {
            RememberLastUser = true;
          };
        };
      };
    };
    # Disable the X11 windowing system. Make the default pure Wayland.
    xserver = {
      enable = false;
      # The video drivers are still set under xserver, also for wayland,
      # even though xserver is disabled.
      videoDrivers = [
        "nvidia"
      ];
    };
  };
  qt = {
    platformTheme = "kde";
    style = "breeze";
  };
  environment = {
    systemPackages = with pkgs; [
      alsa-plugins
      git
      git-credential-manager
      kdePackages.plasma-systemmonitor
      lm_sensors
      nixd
      openssl
    ];
  };

  # Enable sound with pipewire.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.jev = {
    initialPassword = "1234abcd";
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      nixfmt
      vscodium
    ];
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    prompt.enable = false;
  };
  programs.firefox.enable = true;
  nixpkgs.config.allowUnfree = true;

  # Manage per-user dotfiles/app configs (e.g. Plasma System Monitor pages) declaratively.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # Renames pre-existing plain files instead of failing when home-manager wants to manage them.
    backupFileExtension = "hm-backup";
    users.jev = {
      home.stateVersion = "26.05";
      programs.git.settings.credential."https://github.com".helper =
        "${pkgs.git-credential-manager}/bin/git-credential-manager";
    };
  };

  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = stateVersion; # Did you read the comment?
  system.autoUpgrade.channel = "https://nixos.org/channels/nixos-26.05/";
}
