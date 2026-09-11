{ ... }:
let
  workloadService = "acme";
  rootDomain = "raboes28.nl";
  certWorkload = "idm";
in
{
  security = {
    "${workloadService}" = {
      certs =
        let
          certDomain = "${certWorkload}.${rootDomain}";
          idmCertPath = "/var/lib/private/kanidm";
        in
        {
          "${certDomain}" = {
            domain = "${certDomain}";
            inheritDefaults = true;
            postRun = ''
              cp -fpL key.pem ${idmCertPath}/key.pem
              cp -fpL fullchain.pem ${idmCertPath}/fullchain.pem
              chown kanidm:kanidm ${idmCertPath}/key.pem
              chown kanidm:kanidm ${idmCertPath}/fullchain.pem
              chmod 760 ${idmCertPath}/key.pem
              chmod 764 ${idmCertPath}/fullchain.pem
            '';
          };
        };
    };
  };
}
