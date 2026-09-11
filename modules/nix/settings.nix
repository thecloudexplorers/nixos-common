{ lib, ... }:
{
  nixpkgs = {
    # Ensure builds are done on the same platform as the host system.
    hostPlatform = lib.mkDefault "x86_64-linux";
    buildPlatform = lib.mkDefault "x86_64-linux";
    # Ensure 'unfree' packages such as NVIDIA drivers are allowed.
    config.allowUnfree = lib.mkDefault true;
  };
  nix = {
    settings = {
      # Enable support for flakes.
      # https://github.com/NixOS/rfcs/pull/136
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Optimise means 'link duplicate packages to save space'.
      auto-optimise-store = lib.mkDefault true;
      download-buffer-size = lib.mkDefault 524288000;
      # max-call-depth default is 10k. Beware of stack overflow.
      # https://blog.kleisli.io/post/trampolining-nix-with-generic-closure
      max-call-depth = lib.mkDefault 15000;
      substituters = [
        "https://cache.nixos.org?priority=10"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      # All users are allowed to *read* the Nix store, but only trusted users
      # can write to it.
      allowed-users = [
        "*"
      ];
      # All users are allowed to *read* the Nix store, but only trusted users
      # can write to it.
      trusted-users = [
        "@wheel"
      ];
    };
    # Automatic optimise every day at 01:30 hours.
    optimise = {
      automatic = lib.mkDefault true;
      dates = [ "01:30" ];
    };
    # Garbage collect throws away unused packages and old generations of
    # the system/user profiles. This is important to keep the Nix store from
    # growing too large. This includes .iso images, output by generators.
    gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault "daily";
      # With frequent rebuilds and upgrades 14 days should be enough to keep
      # the system running smoothly. This is a good balance between keeping
      # the system clean and not deleting packages that are still in use.
      options = lib.mkDefault "--delete-older-than 14d";
    };
  };
  # Since the upgrade process *will* pull content from the internet, we need
  # to ensure that the network is up before starting the upgrade process.
  systemd.services.nixos-upgrade-start.after = [ "network.target" ];
}
