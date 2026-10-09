{ ... }:
let
  workloadName = "khadgar";
  workloadNode = 1;
in
{
  systemd.tmpfiles.rules = [
    # Persist the Hermes state (config, sessions, memory, workspace) on the
    # SSD-backed volume. 567 is the static uid/gid of the hermes user in users.nix.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/hermes 0750 567 567 -"
    "z /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/hermes 0750 567 567 -"
    # Holds hermes.env with the API keys and dashboard credentials. Populated
    # manually, see the khadgar README. The container reads it as root, so no
    # other user needs access.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/secrets/hermes 0700 root root -"
    "z /mnt/ssd/${workloadName}/${toString workloadNode}/secrets/hermes 0700 root root -"
  ];
}
