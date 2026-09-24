{ pkgs, ... }:
let
  workloadStateVersion = "26.05";
in
{
  imports = [
    # Workload Specific
    ./service-postgresql.nix
  ];
  environment.systemPackages = with pkgs; [ postgresql ];
  system.stateVersion = workloadStateVersion;
}
