{ pkgs, ... }:
let
  workloadStateVersion = "26.05";
in
{
  imports = [
    # Workload Specific
    ./nextcloud/service-nextcloud.nix
  ];
  environment.systemPackages = with pkgs; [ openssl ];
  system.stateVersion = workloadStateVersion;
}
