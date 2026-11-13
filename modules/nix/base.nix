{
  config,
  lib,
  ...
}:

# Base Nix and NixOS settings: substituters, garbage collection, store
# optimisation, automatic upgrades, and the nixpkgs platform/unfree defaults.
#
# Contract:
# Consumers import this module and only tune the options declared below,
# e.g.:
#
#   tce.services.common-modules.nixBase = {
#     trustedUsers = [ "@wheel" "deploy" ];
#     gc.options = "--delete-older-than 30d";
#   };

let
  cfg = config.tce.services.common-modules.nixBase;
in
{
  options.tce.services.common-modules.nixBase = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the base Nix/NixOS settings block.";
    };

    hostPlatform = lib.mkOption {
      type = lib.types.str;
      default = "x86_64-linux";
      description = "Default host platform for nixpkgs.";
    };

    buildPlatform = lib.mkOption {
      type = lib.types.str;
      default = "x86_64-linux";
      description = "Default build platform for nixpkgs.";
    };

    allowUnfree = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow unfree packages in nixpkgs by default.";
    };

    experimentalFeatures = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "nix-command"
        "flakes"
      ];
      description = "Nix experimental features to enable.";
    };

    downloadBufferSize = lib.mkOption {
      type = lib.types.int;
      default = 268435456; # 256 MiB
      description = "Size of the buffer Nix uses when downloading files.";
    };

    # max-call-depth default is 10k. Beware of stack overflow.
    # https://blog.kleisli.io/post/trampolining-nix-with-generic-closure
    maxCallDepth = lib.mkOption {
      type = lib.types.int;
      default = 15000;
      description = "Maximum Nix evaluation call depth.";
    };

    substituters = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "https://cache.nixos.org?priority=10"
        "https://nix-community.cachix.org"
        "https://cache.nixos-cuda.org"
      ];
      description = "Binary cache substituters, in priority order.";
    };

    trustedPublicKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      ];
      description = "Public keys trusted for the substituters above.";
    };

    allowedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "*" ];
      description = "Users allowed to connect to the Nix daemon.";
    };

    trustedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "@wheel" ];
      description = "Users trusted by the Nix daemon for privileged operations.";
    };

    gc = {
      automatic = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable automatic garbage collection of the Nix store.";
      };

      dates = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "When to run automatic garbage collection.";
      };

      options = lib.mkOption {
        type = lib.types.str;
        default = "--delete-older-than 14d";
        description = "Options passed to the garbage collector.";
      };
    };

    optimise = {
      automatic = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable automatic optimisation of the Nix store.";
      };

      dates = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "01:30" ];
        description = "When to run automatic store optimisation.";
      };
    };

    autoUpgrade = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable automatic NixOS upgrades.";
      };

      allowReboot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow an automatic reboot after an upgrade.";
      };

      dates = lib.mkOption {
        type = lib.types.str;
        default = "02:30";
        description = "When to run automatic upgrades.";
      };

      randomizedDelaySec = lib.mkOption {
        type = lib.types.str;
        default = "30min";
        description = "Randomized delay before running an automatic upgrade.";
      };
    };

    stateVersion = lib.mkOption {
      type = lib.types.str;
      default = "26.05";
      description = ''
        NixOS release from which the default settings for stateful data, like
        file locations and database versions on the system, were taken. It is
        perfectly fine and recommended to leave this value at the release
        version of the first install of the system. Before changing this value
        read the documentation for this option (e.g. man configuration.nix or
        on https://nixos.org/nixos/options.html).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs = {
      hostPlatform = cfg.hostPlatform;
      buildPlatform = cfg.buildPlatform;
      config.allowUnfree = cfg.allowUnfree;
    };

    nix = {
      settings = {
        experimental-features = cfg.experimentalFeatures;
        download-buffer-size = cfg.downloadBufferSize;
        max-call-depth = cfg.maxCallDepth;
        substituters = cfg.substituters;
        trusted-public-keys = cfg.trustedPublicKeys;
        allowed-users = cfg.allowedUsers;
        trusted-users = cfg.trustedUsers;
      };
      optimise = {
        automatic = cfg.optimise.automatic;
        dates = cfg.optimise.dates;
      };
      gc = {
        automatic = cfg.gc.automatic;
        dates = cfg.gc.dates;
        options = cfg.gc.options;
      };
    };

    system = {
      autoUpgrade = {
        enable = cfg.autoUpgrade.enable;
        allowReboot = cfg.autoUpgrade.allowReboot;
        dates = cfg.autoUpgrade.dates;
        randomizedDelaySec = cfg.autoUpgrade.randomizedDelaySec;
      };
      stateVersion = cfg.stateVersion;
    };

    # Wait for the network before starting an automatic upgrade.
    systemd.services.nixos-upgrade-start.after = lib.mkIf cfg.autoUpgrade.enable [
      "network.target"
    ];
  };
}
