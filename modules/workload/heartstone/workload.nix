{ ... }:
let
  workloadStateVersion = "26.05";
in
{
  imports = [
    # Workload Specific
    ./service-kanidm.nix
  ];
  system.stateVersion = workloadStateVersion;
}
