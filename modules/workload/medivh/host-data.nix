{ ... }:
let
  rootDomain = "raboes28.nl";
  workloadName = "medivh";
  workloadNode = 1;
  workloadService = "acme";
  heartstoneWorkloadName = "heartstone";
  heartstoneWorkloadDomain = "idm.${rootDomain}";
in
{
  systemd.tmpfiles.rules = [
    # acme stores its certificate/renewal data under /var/lib/acme and the
    # workload user is uid 966.
    # 0750 = owner rwx, group r-x, other ---:
    #   - owner (uid 966): read/write/create/delete files and dirs
    #   - group: read/enter directory, but cannot create or delete
    #   - other: no access
    # This gives the service full control while keeping access limited to the
    # service group.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService} 0750 966 966 -"
    "z /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService} 0750 966 966 -"
    # Logs follow the same ownership model as the application data.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/var/log/${workloadService} 0750 966 966 -"
    "z /mnt/ssd/${workloadName}/${toString workloadNode}/var/log/${workloadService} 0750 966 966 -"
    # The TransIP environment file is shared with the acme service but should not
    # be world-readable; it only needs owner access for the service runtime.
    "d /mnt/ssd/${workloadName}/environments 0750 966 966 -"
    "z /mnt/ssd/${workloadName}/environments 0750 966 966 -"
    # The environment secret is highly sensitive, so it is restricted to the
    # acme UID/GID only.
    # 0700 = owner rwx, group ---, other ---:
    #   - owner (uid 966): full access (read/write/create/delete)
    #   - group: no access
    #   - other: no access
    "d /mnt/ssd/${workloadName}/secrets 0700 966 966 -"
    "z /mnt/ssd/${workloadName}/secrets 0700 966 966 -"
    # The certificate chain for the idm domain is mounted from the heartstone
    # workload and must be readable/writable by the acme service when it renews it.
    "d /mnt/ssd/${heartstoneWorkloadName}/var/lib/${workloadService}/${heartstoneWorkloadDomain} 0750 966 966 -"
    "z /mnt/ssd/${heartstoneWorkloadName}/var/lib/${workloadService}/${heartstoneWorkloadDomain} 0750 966 966 -"
  ];
}
