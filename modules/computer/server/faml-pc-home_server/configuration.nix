# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  inputs,
  lib,
  pkgs,
  stateVersion,
  ...
}:

{
  imports = [
    ## Import modules from the 'inputs' of the flake.
    # Import Disko for local use.
    inputs.disko.nixosModules.disko
    # Import home-manager's NixOS module.
    inputs.home-manager.nixosModules.default

    ## Import the Nix modules specific to this computer.
    # This contains all hardware specific config, except disks.
    ./hardware-configuration.nix
    # This is the specific disk drives configuration.
    ./disko-config.nix
    ./networking.nix

    ## Import Nix modules with generic settings for all computers.
    # These are all 'nix' settings, such as nix store optimisation.
    ../../../nix/settings.nix

    ## Workloads to be hosted on this server
    # Import all containers here
    ../../../workload/medivh/host-data.nix
    ../../../workload/medivh/container-1/container-1.nix
    ../../../workload/heartstone/host-data.nix
    ../../../workload/heartstone/container-1/container-1.nix
    ../../../workload/dalaran/host-data.nix
    ../../../workload/dalaran/container-1/container-1.nix

    ## Services running on this server
    ## Import all services here
    ../../../services/kanidm-client.nix

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
    unsafeAllowHibernation = false;
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
    "drivetemp"
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
  # Required by redis (used by containerized workloads, e.g. Nextcloud) to
  # avoid background save/replication failures under low memory conditions.
  # This is a host-wide kernel setting; containers share the host kernel and
  # cannot set it themselves.
  boot.kernel.sysctl."vm.overcommit_memory" = 1;
  boot.zfs.forceImportRoot = false;
  # ZFS will also mount the ZFS partitions. This will lead to conflicts.
  systemd.services.zfs-mount.enable = false;
  services.zfs.autoScrub.enable = true;
  ##############################
  # End of ZFS specific stuff! #
  ##############################

  # This is the basic bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Central European Time (CET/CEST)
  time.timeZone = "Europe/Amsterdam";

  # Keep the system language as-is, but use Dutch time/date formatting.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "nl_NL.UTF-8";
  };
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "nl_NL.UTF-8/UTF-8"
  ];

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
      btop
      git
      git-credential-manager
      kdePackages.plasma-systemmonitor
      lm_sensors
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
      nixd
      nixfmt
      vscode
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
      imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

      home.stateVersion = "26.05";

      home.packages = with pkgs; [
        btop
      ];

      xdg.configFile."btop/btop.conf".text = ''
        color_theme = "Default"
        theme_background = False
        truecolor = True
        force_tty = False
        updates = 0
        update_ms = 2000
        proc_tree = True
        proc_colors = True
        show_cpu_name = True
        show_cpu_freq = True
        check_temp = true
        cpu_sensor = "Auto"
        show_coretemp = true
        show_gpu_info = "On"
        temp_scale = "celsius"
        graphs = True
        shown_gpus = "nvidia amd intel apple"
        disks_filter = ""
      '';

      xdg.dataFile."plasma-systemmonitor/temperatures.page".text = ''
        [Face-170000000000001][Appearance]
        Title=CPU Usage
        chartFace=org.kde.ksysguard.piechart

        [Face-170000000000001][Sensors]
        highPrioritySensorIds=["cpu/all/usage"]
        totalSensors=["cpu/all/usage"]

        [Face-170000000000001][org.kde.ksysguard.piechart][General]
        showLegend=false

        [Face-170000000000002][Appearance]
        Title=Memory
        chartFace=org.kde.ksysguard.piechart

        [Face-170000000000002][Sensors]
        highPrioritySensorIds=["memory/physical/used"]
        totalSensors=["memory/physical/used","memory/physical/total"]

        [Face-170000000000002][org.kde.ksysguard.piechart][General]
        showLegend=false

        [Face-170000000000003][Appearance]
        Title=GPU Usage
        chartFace=org.kde.ksysguard.piechart

        [Face-170000000000003][Sensors]
        highPrioritySensorIds=["gpu/all/usage"]
        totalSensors=["gpu/all/usage"]

        [Face-170000000000003][org.kde.ksysguard.piechart][General]
        showLegend=false

        [Face-170000000000004][Appearance]
        Title=CPU Core Temperatures
        chartFace=org.kde.ksysguard.linechart

        [Face-170000000000004][Sensors]
        highPrioritySensorIds=["cpu/cpu[0-9]+/temperature"]

        [Face-170000000000004][org.kde.ksysguard.linechart][General]
        rangeAutoY=true

        [Face-170000000000005][Appearance]
        Title=CPU Temperature
        chartFace=org.kde.ksysguard.piechart

        [Face-170000000000005][Sensors]
        highPrioritySensorIds=["cpu/all/averageTemperature"]
        totalSensors=["cpu/all/averageTemperature"]

        [Face-170000000000005][org.kde.ksysguard.piechart][General]
        rangeAuto=false
        rangeTo=110
        showLegend=false

        [Face-170000000000006][Appearance]
        Title=NVMe SSD Temperatures
        chartFace=org.kde.ksysguard.textonly

        [Face-170000000000006][Sensors]
        highPrioritySensorIds=["lmsensors/nvme-pci-.*/temp[0-9]+"]

        [Face-170000000000006][SensorLabels]
        lmsensors/nvme-pci-0200/temp1=OS SSD Composite
        lmsensors/nvme-pci-0200/temp2=OS SSD Sensor 1
        lmsensors/nvme-pci-0200/temp3=OS SSD Sensor 2
        lmsensors/nvme-pci-0300/temp1=Data SSD Composite
        lmsensors/nvme-pci-0300/temp2=Data SSD Sensor 1
        lmsensors/nvme-pci-0300/temp3=Data SSD Sensor 2

        [Face-170000000000006][org.kde.ksysguard.textonly][General]
        groupByTotal=true

        [Face-170000000000007][Appearance]
        Title=Network
        chartFace=org.kde.ksysguard.textonly

        [Face-170000000000007][Sensors]
        highPrioritySensorIds=["network/(?!all).*/download","network/(?!all).*/upload","network/(?!all).*/ipv4address"]
        totalSensors=["network/(?!all).*/network"]

        [Face-170000000000007][org.kde.ksysguard.textonly][General]
        groupByTotal=true

        [Face-170000000000008][Appearance]
        Title=Disk Usage
        chartFace=org.kde.ksysguard.horizontalbars

        [Face-170000000000008][Sensors]
        highPrioritySensorIds=["disk/(?!all).*/used"]

        [Face-170000000000009][Appearance]
        Title=Fans
        chartFace=org.kde.ksysguard.textonly

        [Face-170000000000009][Sensors]
        highPrioritySensorIds=["lmsensors/.*/fan.*"]

        [Face-170000000000009][org.kde.ksysguard.textonly][General]
        groupByTotal=true

        [page]
        Title=Temperatures
        actionsFace=
        icon=speedometer
        loadType=
        margin=2
        version=1

        [page][row-0]
        Title=Overview
        heightMode=minimum
        isTitle=false
        name=row-0

        [page][row-0][column-0]
        name=column-0
        noMargins=false
        showBackground=true

        [page][row-0][column-0][section-0]
        face=Face-170000000000001
        isSeparator=false
        name=section-0

        [page][row-0][column-1]
        name=column-1
        noMargins=false
        showBackground=true

        [page][row-0][column-1][section-0]
        face=Face-170000000000002
        isSeparator=false
        name=section-0

        [page][row-0][column-2]
        name=column-2
        noMargins=false
        showBackground=true

        [page][row-0][column-2][section-0]
        face=Face-170000000000003
        isSeparator=false
        name=section-0

        [page][row-1]
        Title=Thermals
        heightMode=balanced
        isTitle=false
        name=row-1

        [page][row-1][column-0]
        name=column-0
        noMargins=false
        showBackground=true

        [page][row-1][column-0][section-0]
        face=Face-170000000000004
        isSeparator=false
        name=section-0

        [page][row-1][column-1]
        name=column-1
        noMargins=false
        showBackground=true

        [page][row-1][column-1][section-0]
        face=Face-170000000000005
        isSeparator=false
        name=section-0

        [page][row-1][column-1][section-1]
        face=Face-170000000000006
        isSeparator=false
        name=section-1

        [page][row-1][column-2]
        name=column-2
        noMargins=false
        showBackground=true

        [page][row-1][column-2][section-0]
        face=Face-170000000000009
        isSeparator=false
        name=section-0

        [page][row-2]
        Title=System
        heightMode=balanced
        isTitle=false
        name=row-2

        [page][row-2][column-0]
        name=column-0
        noMargins=false
        showBackground=true

        [page][row-2][column-0][section-0]
        face=Face-170000000000008
        isSeparator=false
        name=section-0

        [page][row-2][column-1]
        name=column-1
        noMargins=false
        showBackground=true

        [page][row-2][column-1][section-0]
        face=Face-170000000000007
        isSeparator=false
        name=section-0
      '';

      programs.plasma = {
        enable = true;
        workspace = {
          colorScheme = "BreezeDark";
        };
      };

      programs.git.settings.credential."https://github.com".helper =
        "${pkgs.git-credential-manager}/bin/git-credential-manager";
    };
  };

  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = stateVersion; # Did you read the comment?
  system.autoUpgrade.channel = "https://nixos.org/channels/nixos-26.05/";
}
