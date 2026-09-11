{
  pkgs,
  config,
  modulesPath,
  lib,
  ...
}:
# BEGIN PARAMS
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
# END PARAMS
{
  # BODY
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-base.nix" ];
  # Enable flakes so nixos-install doesn't need --extra-experimental-features.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  isoImage = {
    edition = "graphical";
    showConfiguration = lib.mkDefault false;
  };
  specialisation = {
    graphical_plasma_kernel_latest.configuration =
      { config, ... }:
      {
        imports = [
          "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix"
          "${modulesPath}/installer/cd-dvd/latest-kernel.nix"
        ];
        # boot = { kernelPackages = lib.mkForce pkgs.linuxPackages_6_12; };
        isoImage = {
          showConfiguration = true;
          configurationName = "Plasma (Linux ${config.boot.kernelPackages.kernel.version})";
        };
      };
  };
  boot = {
    kernelPackages = lib.mkForce latestKernelPackage;
    zfs = {
      # Since we will be encrypting the ZFS filesystem, we need to ensure that
      # the ZFS kernel module is built with support for encryption. Hibernation
      # is not supported on encrypted ZFS filesystems, so we disable it.
      allowHibernation = false;
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
      disko
      git
      git-credential-manager
      openssl
      busybox
      netcat
      nmap
      # Include the tpm2-tss package so that the ISO can be used to install
      # NixOS on a system with support for configuring a TPM 2.0 chip. This is
      # required for systems with full disk encryption with LUKS and TPM 2.0.
      tpm2-tss
      # Editor for reviewing/editing the flake and configuration files during install.
      vscodium
    ];
  };
  programs.git = {
    enable = true;
    config.credential."https://github.com".helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
  };
  # Enable xrpd remote desktop service so that the ISO can be used to install
  # NixOS through a remote desktop GUI session. The target environment does
  # *not* need to have a graphical desktop environment after install. Just
  # the ISO includes it for *ClickOps* convenience.
  services = {
    xrdp = {
      enable = true;
      port = 3389;
      openFirewall = true;
      defaultWindowManager = "startplasma-x11";
      audio = {
        enable = true;
      };
    };
  };
}
