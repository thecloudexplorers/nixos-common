{ lib, ... }:
let
  workloadName = "ironforge";
  workloadService = "postgresql";
  workloadTCPPort = 5432;
  rootDomain = "raboes28.nl";
  # Dalaran-1's LAN IP, set via a DHCP reservation on the router (see
  # modules/workload/dalaran/container-1/networking-1.nix for its MAC).
  dalaranWorkloadAddressIPv4 = "192.168.1.69";
  acmeCertDirectory = "/var/lib/acme/${workloadName}.${rootDomain}";
  # PostgreSQL enforces that ssl_key_file be owned by the database user (or
  # root); group-read access (as used for nginx/kanidm) is not sufficient.
  # So the ACME-issued cert/key are copied into a local directory postgres
  # itself owns, rather than being read directly from the ACME mount.
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

  # Grant postgres read/traverse access to the ACME-managed certificate
  # directory (gid 966, shared across all containers in this repo via
  # modules/users/users/workloads/acme.nix), so its preStart hook (below)
  # can read the source certificate to copy locally.
  users.users.postgres.extraGroups = [ "acme" ];

  # Copy the ACME-issued certificate into a directory postgres itself owns.
  # This runs as the postgres user (see NixOS's postgresql module), so the
  # copied files satisfy PostgreSQL's requirement that ssl_key_file be
  # owned by the database user.
  systemd.services.postgresql.preStart = lib.mkAfter ''
    mkdir -p ${localCertDirectory}
    cp -fpL ${acmeCertDirectory}/fullchain.pem ${localCertDirectory}/cert.pem
    cp -fpL ${acmeCertDirectory}/key.pem ${localCertDirectory}/key.pem
    chmod 600 ${localCertDirectory}/key.pem
    chmod 644 ${localCertDirectory}/cert.pem
  '';

  networking.firewall.allowedTCPPorts = [ workloadTCPPort ];
}
