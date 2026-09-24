{ ... }:
let
  workloadService = "acme";
  rootDomain = "raboes28.nl";
  certWorkload = "ironforge";
  certDomain = "${certWorkload}.${rootDomain}";
  # Writable staging directory bind mounted into both medivh (this postRun
  # writes into it) and ironforge-1 (postgres reads from it as
  # /var/lib/postgresql/secrets). See modules/workload/medivh/container-1/
  # container-1.nix and modules/workload/ironforge/container-1/container-1.nix.
  postgresCertPath = "/var/lib/private/postgresql";
in
{
  security = {
    "${workloadService}" = {
      certs = {
        "${certDomain}" = {
          domain = "${certDomain}";
          inheritDefaults = true;
          postRun = ''
            cp -fpL key.pem ${postgresCertPath}/key.pem
            cp -fpL fullchain.pem ${postgresCertPath}/cert.pem
            chown postgres:postgres ${postgresCertPath}/key.pem
            chown postgres:postgres ${postgresCertPath}/cert.pem
            chmod 600 ${postgresCertPath}/key.pem
            chmod 644 ${postgresCertPath}/cert.pem
          '';
        };
      };
    };
  };
}
