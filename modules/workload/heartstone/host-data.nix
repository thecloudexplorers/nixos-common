{ ... }:
let
  rootDomain = "raboes28.nl";
  workloadName = "heartstone";
  workloadNode = 1;
  workloadService = "kanidm";
  workloadDomain = "idm.${rootDomain}";
in
{
  systemd.tmpfiles.rules = [
    # kanidm stores its primary database state under /var/lib/kanidm.
    # 0750 = owner rwx, group r-x, other ---:
    #   - owner (uid 960): read/write/create/delete files and dirs
    #   - group: read/enter directory, but cannot create or delete
    #   - other: no access
    # This keeps the service fully in control while still allowing a helper group
    # to inspect the data without modifying it.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService} 0750 960 960 -"
    "z /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService} 0750 960 960 -"
    # TLS material is sensitive.
    # 0700 = owner rwx, group ---, other ---:
    #   - owner (uid 960): full access (read/write/create/delete)
    #   - group: no access
    #   - other: no access
    # This keeps the private key and cert chain accessible only to the kanidm
    # service itself.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService}/secrets 0700 960 960 -"
    "z /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService}/secrets 0700 960 960 -"
    # Backups are retained on a separate dataset but still belong to the kanidm
    # service account so backup tooling can read/write without broad permissions.
    "d /mnt/zdata/${workloadName}/${toString workloadNode}/backups 0750 960 960 -"
    "z /mnt/zdata/${workloadName}/${toString workloadNode}/backups 0750 960 960 -"
    # The ACME challenge directory is mounted read-only into the kanidm workload
    # when it needs to serve the letsencrypt certificate material.
    "d /mnt/ssd/${workloadName}/var/lib/acme/${workloadDomain} 0750 966 966 -"
    "z /mnt/ssd/${workloadName}/var/lib/acme/${workloadDomain} 0750 966 966 -"
  ];
}
