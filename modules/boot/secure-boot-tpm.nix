{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# This module automates Lanzaboote and TPM unlocking configuration.
#
# Requirements:
# - A 'lanzaboote' input in your flake (e.g., github:nix-community/lanzaboote)
#
# Contract:
# The user provides the input; this module handles all bootloader,
# initrd, and package requirements. Consumers configure the module
# through the options declared below, e.g.:
#
#   tce.services.common-modules.secureBoot.pkiBundle = "/etc/secureboot";

let
  # Validate that the user provided the necessary input
  lanzaboote = inputs.lanzaboote;
  cfg = config.tce.services.common-modules.secureBoot;
in
{
  imports = [ lanzaboote.nixosModules.lanzaboote ];

  options.tce.services.common-modules.secureBoot = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Secure Boot with TPM-based unlocking via Lanzaboote.";
    };

    pkiBundle = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/sbctl";
      description = "Path to the sbctl PKI bundle containing the db, KEK and PK keys.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      bootspec.enableValidation = true;
      lanzaboote = {
        enable = true;
        pkiBundle = cfg.pkiBundle;
      };
      loader = {
        efi.canTouchEfiVariables = true;
        # Lanzaboote handles the boot process, so we disable the standard
        # loaders. Note: disabling systemd-boot also removes its
        # `boot.loader.grub.enable = mkDefault false`, and on nixos-26.05
        # grub is enabled by default (!boot.isContainer), so grub must be
        # disabled explicitly or its "set devices" assertion fires.
        systemd-boot.enable = false;
        grub.enable = false;
      };
      initrd = {
        availableKernelModules = [
          "encrypted_keys"
          "tpm"
          "trusted"
        ];
      };
    };

    # Standard packages required for provisioning and runtime
    environment.systemPackages = with pkgs; [
      sbctl
      tpm2-tools
      tpm2-tss
    ];
  };
}
