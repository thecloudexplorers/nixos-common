{ pkgs, ... }:
let
  workloadStateVersion = "26.05";
in
{
  imports = [
    # Workload Specific
    ./service-kanidm.nix
  ];
  environment.systemPackages = with pkgs; [ kanidm_1_11 ];
  system.stateVersion = workloadStateVersion;
}
