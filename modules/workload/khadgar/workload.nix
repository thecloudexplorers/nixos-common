{ ... }:
let
  workloadStateVersion = "26.05";
in
{
  imports = [
    # Workload Specific
    ./service-hermes-agent.nix
    ./users.nix
  ];
  system.stateVersion = workloadStateVersion;
}
