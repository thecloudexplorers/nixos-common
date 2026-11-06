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
#   services.common_modules.secureBoot.pkiBundle = "/etc/secureboot";

let
  # Validate that the user provided the necessary input
  lanzaboote = inputs.lanzaboote;
  cfg = config.services.common_modules.secureBoot;
in
{
  imports = [ lanzaboote.nixosModules.lanzaboote ];

  options.services.common_modules.secureBoot = {
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
      lanzaboote.pkiBundle = cfg.pkiBundle;
      loader = {
        efi.canTouchEfiVariables = true;
        # Lanzaboote handles the boot process, so we disable standard systemd-boot
        systemd-boot.enable = false;
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
