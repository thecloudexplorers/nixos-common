{ lib, pkgs, ... }:
let
  workloadService = "kanidm";
  rootDomain = "raboes28.nl";
  serviceDomain = "idm.${rootDomain}";
in
{
  services = {
    "${workloadService}" = {
      package = pkgs.kanidm_1_11;
      server = {
        enable = true;
        settings = {
          domain = "${serviceDomain}";
          origin = "https://${serviceDomain}";
          tls_chain = "/var/lib/${workloadService}/secrets/fullchain.pem";
          tls_key = "/var/lib/${workloadService}/secrets/key.pem";
          db_fs_type = "other";
          online_backup.versions = 5;
        };
      };
    };
  };
  systemd.services."${workloadService}" = {
    serviceConfig = {
      SupplementaryGroups = [
        "acme"
        "sharedstorage"
      ];
      AmbientCapabilities = lib.mkForce [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = lib.mkForce [ "CAP_NET_BIND_SERVICE" ];
    };
  };
}
