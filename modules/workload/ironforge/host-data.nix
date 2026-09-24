{ ... }:
let
  workloadName = "ironforge";
  workloadNode = 1;
  workloadService = "postgresql";
in
{
  systemd.tmpfiles.rules = [
    # Persist PostgreSQL's data directory on the SSD-backed volume.
    # The bind-mounted paths must match the postgres user inside the
    # container, otherwise the postgresql service sees an unsafe owner
    # transition on its data directory.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService} 0750 postgres postgres -"
    "z /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService} 0750 postgres postgres -"
    # Persist PostgreSQL's logs on the same volume.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/var/log/${workloadService} 0750 postgres postgres -"
    "z /mnt/ssd/${workloadName}/${toString workloadNode}/var/log/${workloadService} 0750 postgres postgres -"
  ];
}
