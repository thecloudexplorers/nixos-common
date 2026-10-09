{ ... }:
let
  workloadStateVersion = "26.05";
in
{
  imports = [
    # Workload Specific
    ./service-open-webui.nix
  ];
  system.stateVersion = workloadStateVersion;
}
