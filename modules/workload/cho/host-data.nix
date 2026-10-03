{ ... }:
let
  workloadName = "cho";
  workloadNode = 1;
in
{
  systemd.tmpfiles.rules = [
    # Persist Ollama service state on the SSD-backed volume.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/ollama 0750 433 433 -"
    "z /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/ollama 0750 433 433 -"
    # Keep downloaded models on the larger data volume.
    "d /mnt/zdata/${workloadName}/${toString workloadNode}/var/lib/ollama/models 0750 433 433 -"
    "z /mnt/zdata/${workloadName}/${toString workloadNode}/var/lib/ollama/models 0750 433 433 -"
  ];
}
