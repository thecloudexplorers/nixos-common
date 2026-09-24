{ ... }:
let
  workloadName = "ironforge";
  workloadService = "postgresql";
  workloadTCPPort = 5432;
  rootDomain = "raboes28.nl";
  # Dalaran-1's LAN IP, set via a DHCP reservation on the router (see
  # modules/workload/dalaran/container-1/networking-1.nix for its MAC).
  dalaranWorkloadAddressIPv4 = "192.168.1.69";
in
{
  services = {
    "${workloadService}" = {
      enable = true;
      enableTCPIP = true;
      settings = {
        port = workloadTCPPort;
        ssl = true;
        ssl_cert_file = "/var/lib/acme/${workloadName}.${rootDomain}/cert.pem";
        ssl_key_file = "/var/lib/acme/${workloadName}.${rootDomain}/key.pem";
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

  # Grant postgres read/traverse access to the ACME-managed certificate
  # directory (gid 966, shared across all containers in this repo via
  # modules/users/users/workloads/acme.nix), matching the group-based
  # access pattern already used for nginx/kanidm rather than chown'ing or
  # copying certificate material across containers.
  users.users.postgres.extraGroups = [ "acme" ];

  networking.firewall.allowedTCPPorts = [ workloadTCPPort ];
}
