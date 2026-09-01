{
  pkgs,
  modulesPath,
  lib,
  ...
}:

{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-base.nix" ];
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
    # Needed for https://github.com/NixOS/nixpkgs/issues/58959
    supportedFilesystems = lib.mkForce [
      "lvm"
      "luks"
      "mdadm"
      "ext4"
      "vfat"
    ];
  };
  environment = {
    systemPackages = with pkgs; [
      disko
      git
      openssl
      busybox
      netcat
      nmap
      tpm2-tss
    ];
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
