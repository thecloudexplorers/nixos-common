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
  oidcClientSecretFile = "/tmp/${workloadName}-oidc/${workloadService}-client-secret";
  oidcProviderIdentifier = "kanidm";
  oidcClientId = "nextcloud";
  oidcDiscoveryUri = "https://idm.${rootDomain}/oauth2/openid/${oidcClientId}/.well-known/openid-configuration";
  workloadServiceDataFolder = "/var/lib/${workloadService}/data";
  workloadServiceFolder = "/var/lib/${workloadService}";
  workloadServicePort = 443;
  workloadServiceTalkPort = 3478;
  workloadServiceAddressIPv4 = "0.0.0.0";
  workloadServiceAddressIPv6 = "::";
  # Baleroc-1 (public facing reverse proxy). The IPv4 address is set via a DHCP
  # reservation on the router. The IPv6 address is the stable SLAAC (EUI-64)
  # address derived from its MAC (privacy extensions are disabled).
  proxyAddressIPv4 = "192.168.1.191";
  proxyAddressIPv6 = "2a02:a441:f08f:0:a8e1:bdff:fedd:d240";
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
      # Apps are pinned declaratively via extraApps below, so the writable
      # app store (which requires a writable /var/lib/nextcloud/store-apps
      # directory that isn't created by our tmpfiles rules) is not needed.
      # Leaving this enabled causes occ app:enable to throw "Cannot write
      # into apps directory" since that directory doesn't exist.
      appstoreEnable = false;
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

  # Registers/updates the Kanidm OIDC provider for the "user_oidc" app so
  # users can sign in to Nextcloud with their Kanidm account. Runs on every
  # boot so config drift (e.g. discovery URL/scope changes made here) is
  # reconciled automatically; occ upserts by identifier so this is
  # idempotent. The client secret itself is a host-managed secret, see
  # docs/nextcloud-kanidm-sso.md.
  systemd.services.nextcloud-oidc-setup = {
    description = "Configure the Nextcloud user_oidc provider for Kanidm SSO";
    wantedBy = [ "multi-user.target" ];
    after = [ "nextcloud-setup.service" ];
    requires = [ "nextcloud-setup.service" ];
    script = ''
      ${lib.getExe config.services.nextcloud.occ} user_oidc:provider ${oidcProviderIdentifier} \
        --clientid="${oidcClientId}" \
        --clientsecret-file="$CREDENTIALS_DIRECTORY/oidc-client-secret" \
        --discoveryuri="${oidcDiscoveryUri}" \
        --scope="openid profile email" \
        --unique-uid=0 \
        --mapping-uid=preferred_username
    '';
    serviceConfig = {
      Type = "oneshot";
      LoadCredential = [
        "oidc-client-secret:${oidcClientSecretFile}"
      ]
      ++ config.systemd.services.nextcloud-cron.serviceConfig.LoadCredential;
      inherit (config.systemd.services.nextcloud-cron.serviceConfig) User KillMode;
    };
  };
}
