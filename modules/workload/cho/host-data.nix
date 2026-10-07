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
    # Downloaded models also live on the SSD, inside the state directory above,
    # for fast loading into VRAM.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/ollama/models 0750 433 433 -"
    "z /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/ollama/models 0750 433 433 -"
  ];
}
