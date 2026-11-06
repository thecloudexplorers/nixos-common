{ ... }:
let
  rootDomain = "raboes28.nl";
  workloadName = "brann";
  workloadNode = 1;
  workloadService = "open-webui";
  workloadDomain = "brann.${rootDomain}";
in
{
  systemd.tmpfiles.rules = [
    # Open WebUI runs as a systemd DynamicUser, so its uid is not known here.
    # systemd chowns the state directory to that user when the service starts,
    # which means root-only is enough on the host. It holds the SQLite database
    # (users, chats), uploads and the secret key that signs login sessions, so
    # nobody else needs access. There is deliberately no `z` rule: it would
    # reset the owner to root whenever tmpfiles reruns (for example on a
    # switch), and the running service could then no longer open its database.
    "d /mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService} 0700 root root -"
    # The ACME workload (medivh) writes the certificate here. Creating the
    # directory up front lets brann-1 start before the first certificate has
    # been issued: the bind mount fails to start the container otherwise. The
    # owner is the shared acme uid/gid (966), like the rest of the ACME data.
    "d /mnt/ssd/medivh/1/var/lib/acme/${workloadDomain} 0750 966 966 -"
    "z /mnt/ssd/medivh/1/var/lib/acme/${workloadDomain} 0750 966 966 -"
  ];
}
