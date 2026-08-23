# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    "${fetchTarball "https://github.com/nix-community/disko/archive/master.tar.gz"}/module.nix"
    ./disko-config.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Generate hostId by machine: `head -c 8 /etc/machine-id`
  # Generate hostId at random: `head -c4 /dev/urandom | od -A none -t x4`
  networking.hostId = "8bda2338";
  networking.hostName = "faml-pc-home_server";

  services = {
    desktopManager.plasma6.enable = lib.mkDefault true;
    displayManager = {
      autoLogin.enable = lib.mkDefault false;
      defaultSession = lib.mkDefault "plasma";
      sddm = {
        enable = true;
        wayland.enable = true;
      };
    };
    # Disable the X11 windowing system. Make the default pure Wayland.
    xserver.enable = lib.mkDefault false;
  };
  qt = {
    platformTheme = lib.mkDefault "kde";
    style = lib.mkDefault "breeze";
  };
  environment = {
    systemPackages = with pkgs.kdePackages; [
      plasma-systemmonitor
    ];
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.jev = {
    initialPassword = "1234abcd";
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      vscodium
    ];
  };

  programs.firefox.enable = true;
  programs.git.enable = true;
  nixpkgs.config.allowUnfree = true;

  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?
  system.autoUpgrade.channel = "https://nixos.org/channels/nixos-26.05/";
}
