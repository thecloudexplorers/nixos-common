{ ... }:
let
  workloadName = "dalaran";
  workloadNode = 1;
in
{
  systemd.tmpfiles.rules = [
    # Persist the Nextcloud home directory on the SSD-backed volume.
    # The bind-mounted paths must match the nextcloud user inside the container,
    # otherwise the setup service sees an unsafe owner transition on /data.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/nextcloud 0750 nextcloud nextcloud -"
    "z /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/nextcloud 0750 nextcloud nextcloud -"
    # Store the Nextcloud user data on the larger data volume.
    "d /mnt/zdata/${workloadName}/${toString workloadNode}/var/lib/nextcloud/data 0750 nextcloud nextcloud -"
    "z /mnt/zdata/${workloadName}/${toString workloadNode}/var/lib/nextcloud/data 0750 nextcloud nextcloud -"
    "d /mnt/zdata/${workloadName}/${toString workloadNode}/var/lib/nextcloud/data/config 0750 nextcloud nextcloud -"
    "z /mnt/zdata/${workloadName}/${toString workloadNode}/var/lib/nextcloud/data/config 0750 nextcloud nextcloud -"
    # Bootstrap the initial admin password from a host-managed secret.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/secrets/admin 0700 root root -"
    "z /mnt/ssd/${workloadName}/${toString workloadNode}/secrets/admin 0700 root root -"
  ];
}
