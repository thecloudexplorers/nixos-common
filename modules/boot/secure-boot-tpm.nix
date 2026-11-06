{
  config,
  lib,
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
# initrd, and package requirements.

let
  # Validate that the user provided the necessary input
  lanzaboote = inputs.lanzaboote;
in
{
  imports = [ lanzaboote.nixosModules.lanzaboote ];

  boot = {
    bootspec.enableValidation = true;
    lanzaboote = {
      # Use the user-provided path or default to /var/lib/sbctl
      pkiBundle = config.services.common_modules.secureBoot.pkiBundle || "/var/lib/sbctl";
    };
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
  environment.systemPackages = with lib.ctx.pkgs; [
    sbctl
    tpm2-tools
    tpm2-tss
  ];

  # Reference configuration point for the consumer
  # This allows downstream users to override specifics like pkiBundle
  # without touching this module's code.
  services.common_modules = {
    secureBoot = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };
}
