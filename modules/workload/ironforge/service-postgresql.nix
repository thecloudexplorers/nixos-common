{ ... }:
let
  workloadService = "postgresql";
  workloadTCPPort = 5432;
  # Dalaran-1's LAN IP, set via a DHCP reservation on the router (see
  # modules/workload/dalaran/container-1/networking-1.nix for its MAC).
  dalaranWorkloadAddressIPv4 = "192.168.1.69";
  # PostgreSQL enforces that ssl_key_file be owned by the database user (or
  # root); group-read access (as used for nginx/kanidm) is not sufficient.
  # So the ACME-issued cert/key are copied into this directory (owned by
  # postgres) by medivh's ACME postRun hook rather than being read directly
  # from the ACME mount. See modules/workload/medivh/acme/service-acme-ironforge.nix
  # and modules/workload/ironforge/container-1/container-1.nix for the
  # shared bind mount that backs this path.
  localCertDirectory = "/var/lib/${workloadService}/secrets";
in
{
  services = {
    "${workloadService}" = {
      enable = true;
      enableTCPIP = true;
      settings = {
        port = workloadTCPPort;
        ssl = true;
        ssl_cert_file = "${localCertDirectory}/cert.pem";
        ssl_key_file = "${localCertDirectory}/key.pem";
      };
      ensureUsers = [
        {
          name = "nextcloud";
          ensureDBOwnership = true;
          ensureClauses.login = true;
        }
      ];
      ensureDatabases = [
        "nextcloud"
      ];
      authentication = ''
        #type database    DBuser      interface                   auth-method
        host  nextcloud   nextcloud   ${dalaranWorkloadAddressIPv4}/32  trust
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ workloadTCPPort ];
}
