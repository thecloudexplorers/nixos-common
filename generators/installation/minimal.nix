{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
# PARAMS
let
  # Ensure the kernel applied to this this ISO is compatible with ZFS,
  # so that the ISO can be used to install NixOS on a ZFS root filesystem.
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
{
  # BODY
  imports = [
    # This is the base configuration for the NixOS installation CD,
    # from the official nixos/nixpkgs repository.
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];
  # Enable flakes so nixos-install doesn't need --extra-experimental-features.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # use the latest Linux kernel
  boot = {
    kernelPackages = lib.mkForce latestKernelPackage;
    zfs = {
      # Since we will be encrypting the ZFS filesystem, we need to ensure that
      # the ZFS kernel module is built with support for encryption. Hibernation
      # is not supported on encrypted ZFS filesystems, so we disable it.
      unsafeAllowHibernation = false;
      # The ISO does not boot from ZFS, so there is no root pool to force
      # import. Matches the host config and the default from 26.11 on.
      forceImportRoot = false;
    };
    # Needed for https://github.com/NixOS/nixpkgs/issues/58959
    supportedFilesystems = lib.mkForce [
      "lvm"
      "luks"
      "zfs"
      "btrfs"
      "mdadm"
      "ext4"
      "reiserfs"
      "vfat"
      "f2fs"
      "xfs"
      "ntfs"
      "cifs"
    ];
  };
  environment = {
    systemPackages = with pkgs; [
      # This ensures you can run disko straight from the live ISO without
      # having to install it first.
      disko
      git
      openssl
      busybox
      netcat
      nmap
      # Include the tpm2-tss package so that the ISO can be used to install
      # NixOS on a system with support for configuring a TPM 2.0 chip. This is
      # required for systems with full disk encryption with LUKS and TPM 2.0.
      tpm2-tss
    ];
  };
  # *Disable* the KDE Plasma Desktop Environment. This is a CLI only installer
  # ISO, so we don't want to include any graphical desktop environments or
  # display managers. Helps keep the installer footprint small.
  services = {
    desktopManager = {
      plasma6 = {
        enable = false;
      };
    };
    displayManager = {
      sddm = {
        enable = false;
        autoNumlock = true;
        wayland = {
          enable = false;
        };
      };
    };
    xrdp = {
      enable = false;
    };
    # Disable CUPS (printing services) to ensure it does not interfere with
    # the installer image.
    printing = {
      enable = false;
    };
  };
  networking = {
    networkmanager = {
      # Mutually exclusive with networking.wireless
      enable = lib.mkForce false;
    };
  };
}
