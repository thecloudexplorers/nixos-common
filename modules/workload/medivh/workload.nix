{ pkgs, ... }:
let
  workloadStateVersion = "26.05";
in
{
  imports = [
    # Workload Specific
    ./acme/service-acme.nix
    ./acme/service-acme-idm.nix
    ./acme/service-acme-nextcloud.nix
    ./acme/service-acme-ironforge.nix
    ./acme/service-acme-cho.nix
    ./acme/service-acme-khadgar.nix
    ./acme/service-acme-brann.nix
  ]
  # Generic modules
  ++ [
    # Groups
    ../../users/groups/shared/shared-storage.nix

    # Users (system)
    ../../users/users/workloads/acme.nix
  ];
  environment.systemPackages = with pkgs; [ openssl ];
  system.stateVersion = workloadStateVersion;
}
