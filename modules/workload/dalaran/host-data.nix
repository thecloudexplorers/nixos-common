{ ... }:
let
  workloadName = "dalaran";
  workloadNode = 1;
in
{
  systemd.tmpfiles.rules = [
    # Persist the Nextcloud home directory on the SSD-backed volume.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/nextcloud 0750 0 0 -"
    "z /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/nextcloud 0750 0 0 -"
    # Store the Nextcloud user data on the larger data volume.
    "d /mnt/zdata/${workloadName}/${toString workloadNode}/var/lib/nextcloud/data 0750 0 0 -"
    "z /mnt/zdata/${workloadName}/${toString workloadNode}/var/lib/nextcloud/data 0750 0 0 -"
    # Bootstrap the initial admin password from a host-managed secret.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/secrets/admin 0700 0 0 -"
    "z /mnt/ssd/${workloadName}/${toString workloadNode}/secrets/admin 0700 0 0 -"
  ];
}
