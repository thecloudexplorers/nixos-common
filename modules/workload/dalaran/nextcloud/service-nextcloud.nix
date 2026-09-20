{ lib, pkgs, ... }:
let
  workloadName = "dalaran";
  workloadService = "nextcloud";
  rootDomain = "raboes28.nl";
  workloadHostName = "${workloadService}.${rootDomain}";
  workloadAdminPasswordFile = "/tmp/${workloadName}-admin/${workloadService}-admin-pass";
  workloadDataDirectory = "/var/lib/${workloadService}/data";
  nginxUser = "nginx";
  nginxGroup = nginxUser;
in
{
  # Grant nginx read/traverse access to the ACME-managed certificate
  # directory (gid 966, shared across all containers in this repo via
  # modules/users/users/workloads/acme.nix), matching the group-based
  # access pattern already used for kanidm/heartstone rather than
  # chown'ing or copying certificate material across containers.
  users.users."${nginxUser}".extraGroups = [ "acme" ];
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

  services = {
    "${workloadService}" = {
      enable = true;
      package = pkgs.nextcloud34;
      hostName = workloadHostName;
      home = "/var/lib/${workloadService}";
      datadir = workloadDataDirectory;
      database.createLocally = true;
      configureRedis = true;
      https = true;
      autoUpdateApps.enable = true;
      maxUploadSize = "16G";
      config = {
        adminuser = "admin";
        adminpassFile = workloadAdminPasswordFile;
        dbtype = "pgsql";
        dbname = workloadService;
        dbuser = workloadService;
      };
      settings = {
        trusted_domains = [ workloadHostName ];
        overwriteprotocol = "https";
        default_phone_region = "NL";
        allow_local_remote_servers = true;
        log_type = "file";
        maintenance = false;
        maintenance_window_start = 1;
        "profile.enabled" = true;
      };
      phpOptions = {
        "opcache.interned_strings_buffer" = "32";
        "opcache.memory_consumption" = "2048";
        "opcache.revalidate_freq" = "60";
        "max_input_time" = "3600";
        "max_execution_time" = "3600";
        "upload_tmp_dir" = "${workloadDataDirectory}/big_temp_file/";
      };
    };

    nginx = {
      enable = true;
      user = nginxUser;
      group = nginxGroup;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      enableReload = true;
      virtualHosts = {
        "${workloadHostName}" = {
          serverName = workloadHostName;
          forceSSL = true;
          extraConfig = "client_body_buffer_size 512M;";
          sslCertificate = "/var/lib/acme/${workloadHostName}/cert.pem";
          sslCertificateKey = "/var/lib/acme/${workloadHostName}/key.pem";
          listen = [
            {
              addr = "0.0.0.0";
              port = 443;
              ssl = true;
            }
            {
              addr = "[::]";
              port = 443;
              ssl = true;
            }
          ];
        };
      };
    };
  };
}
