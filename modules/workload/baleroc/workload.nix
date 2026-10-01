{ ... }:
let
  workloadStateVersion = "26.05";
in
{
  imports = [
    # Workload Specific
    ./service-nginx.nix
  ];
  system.stateVersion = workloadStateVersion;
}
