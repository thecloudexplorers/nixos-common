{
  config,
  lib,
  pkgs,
  ...
}:
let
  workloadName = "dalaran";
  workloadService = "nextcloud";
  rootDomain = "raboes28.nl";
  workloadHostName = "${workloadService}.${rootDomain}";
  workloadAdminPasswordFile = "/tmp/${workloadName}-admin/${workloadService}-admin-pass";
  workloadServiceDataFolder = "/var/lib/${workloadService}/data";
  workloadServiceFolder = "/var/lib/${workloadService}";
  workloadServicePort = 443;
  workloadServiceTalkPort = 3478;
  workloadServiceAddressIPv4 = "0.0.0.0";
  workloadServiceAddressIPv6 = "::";
  proxyAddressIPv4 = "0.0.0.0";
  proxyAddressIPv6 = "::";
  nginxUser = "nginx";
  nginxGroup = nginxUser;
  databaseHost = "ironforge.${rootDomain}";
  databasePort = 5432;
in
{
  environment.systemPackages = with pkgs; [
    # Add ffmpeg for preview of videos
    ffmpeg
  ];

  # Grant nginx read/traverse access to the ACME-managed certificate
  # directory (gid 966, shared across all containers in this repo via
  # modules/users/users/workloads/acme.nix), matching the group-based
  # access pattern already used for kanidm/heartstone rather than
  # chown'ing or copying certificate material across containers.
  users.users."${nginxUser}".extraGroups = [
    "acme"
  ];

  services = {
    "${workloadService}" = {
      enable = true;
      package = pkgs.nextcloud34;
      hostName = workloadHostName;
      home = "/var/lib/${workloadService}";
      datadir = workloadServiceDataFolder;
      # PostgreSQL now runs in the separate "ironforge" container instead of
      # locally inside dalaran; see modules/workload/ironforge.
      database.createLocally = false;
      configureRedis = true;
      https = true;
      maxUploadSize = "16G";
      config = {
        adminuser = "admin";
        adminpassFile = workloadAdminPasswordFile;
        dbtype = "pgsql";
        dbhost = "${databaseHost}:${toString databasePort}";
        dbname = workloadService;
        dbuser = workloadService;
      };
      settings = {
        trusted_domains = [ workloadHostName ];
        trusted_proxies = [
          "${proxyAddressIPv4}"
          "${proxyAddressIPv6}"
        ];
        overwriteprotocol = "https";
        mail_domain = "${rootDomain}";
        "profile.enabled" = true;
        allow_local_remote_servers = true;
        allow_user_to_change_email = false;
        default_phone_region = "NL";
        default_language = "en";
        default_locale = "nl_NL";
        default_timezone = "Europe/Amsterdam";
        log_type = "file";
        lost_password_link = "disabled";
        maintenance = false;
        maintenance_window_start = 1;
        enabledPreviewProviders = [
          "OC\\Preview\\Image"
          "OC\\Preview\\BMP"
          "OC\\Preview\\GIF"
          "OC\\Preview\\HEIC"
          "OC\\Preview\\JPEG"
          "OC\\Preview\\PNG"
          "OC\\Preview\\SVG"
          "OC\\Preview\\WebP"
          "OC\\Preview\\XBitmap"
          "OC\\Preview\\Krita"
          "OC\\Preview\\MarkDown"
          "OC\\Preview\\OpenDocument"
          "OC\\Preview\\PDF"
          "OC\\Preview\\TXT"
          "OC\\Preview\\MP3"
          "OC\\Preview\\Movie"
          "OC\\Preview\\MP4"
          "OC\\Preview\\MKV"
          "OC\\Preview\\AVI"
          "OC\\Preview\\MOV"
          "OC\\Preview\\WMV"
        ];
        "default_socket_timeout" = "3600";
        "files.chunked_upload.max_size" = 512 * 1024 * 1024;
        "max_execution_time" = "3600";
        "max_input_time" = "-1";
        "memory_limit" = "1024M";
        "realpath_cache_size" = "8M";
        "realpath_cache_ttl" = "600";
        "upload_tmp_dir" = "${workloadServiceFolder}/big_temp_file/";

      };
      phpOptions = {
        "opcache.max_accelerated_files" = "5000";
        "opcache.memory_consumption" = "256";
        "opcache.interned_strings_buffer" = "64";
        "opcache.save_comments" = "1";
        "opcache.revalidate_freq" = "60";
        "opcache.jit" = "1255";
        "opcache.jit_buffer_size" = "128M";

        "apc.enable_cli" = "1";
        "apc.shm_size" = "128M";
        "output_buffering" = "0";
      };
      autoUpdateApps.enable = true;
      extraAppsEnable = true;
      extraApps = with config.services.nextcloud.package.packages.apps; {
        # List of apps we want to install and are already packaged in
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/nextcloud/packages/nextcloud-apps.json
        inherit
          bookmarks
          calendar # Calendar app
          checksum
          contacts # Contacts app
          cookbook # Cookbook app
          cospend
          deck # For Kanban stuff
          drawio
          end_to_end_encryption # Encryption stuff
          gpoddersync # Podcast Sync
          integration_openai # For Nextcloud Assistant
          maps # Maps app
          news # News app
          notes # Notes app
          previewgenerator
          richdocuments
          spreed # NC Talk app
          tasks # Tasks app
          twofactor_admin # 2FA Admin app
          twofactor_webauthn
          user_oidc # OIDC App
          ;
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
              addr = workloadServiceAddressIPv4;
              port = workloadServicePort;
              ssl = true;
            }
            {
              addr = "[${workloadServiceAddressIPv6}]";
              port = workloadServicePort;
              ssl = true;
            }
          ];
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    workloadServicePort
    workloadServiceTalkPort
  ];

  networking.firewall.allowedUDPPorts = [
    workloadServicePort
    workloadServiceTalkPort
  ];

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

  systemd.services.nextcloud-cron.path = [
    pkgs.ffmpeg
  ];
}
