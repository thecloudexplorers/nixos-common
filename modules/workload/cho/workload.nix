{ ... }:
let
  workloadStateVersion = "26.05";
in
{
  imports = [
    # Workload Specific
    ./service-ollama.nix
    ./users.nix
  ];
  system.stateVersion = workloadStateVersion;
}
