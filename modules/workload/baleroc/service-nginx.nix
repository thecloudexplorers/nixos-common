{ ... }:
let
  workloadService = "nginx";
  workloadServiceUser = workloadService;
  workloadServiceGroup = workloadServiceUser;
  rootDomain = "raboes28.nl";
  nextcloudHostName = "nextcloud.${rootDomain}";
  # Dalaran-1's LAN IP, set via a DHCP reservation on the router (MAC
  # 7a:1e:46:b4:6f:11). Resolved as a static hosts entry so the proxy always
  # reaches the container directly, instead of looping back through the public
  # DNS record / router (which points at this very proxy). The backend still
  # serves and is verified against the real certificate for
  # ${nextcloudHostName}.
  dalaranAddressIPv4 = "192.168.1.69";
  nextcloudProxyPass = "https://${nextcloudHostName}";
in
{
  # Grant nginx read/traverse access to the ACME-managed certificate
  # directory (gid 966, shared across all containers in this repo via
  # modules/users/users/workloads/acme.nix).
  users.users."${workloadServiceUser}".extraGroups = [ "acme" ];

  networking.extraHosts = ''
    ${dalaranAddressIPv4} ${nextcloudHostName}
  '';

  services."${workloadService}" = {
    enable = true;
    user = workloadServiceUser;
    group = workloadServiceGroup;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    statusPage = false;
    enableReload = true;
    # Do not advertise the nginx version to the public internet.
    serverTokens = false;
    virtualHosts = {
      # Catch-all for anything not addressed to a known hostname (scanners,
      # requests by bare IP). TLS handshakes for unknown names are refused
      # outright and plain HTTP requests are dropped (444), so no certificate
      # or backend is ever disclosed.
      "_" = {
        default = true;
        rejectSSL = true;
        locations."/".return = "444";
      };
      "${nextcloudHostName}" = {
        serverName = nextcloudHostName;
        forceSSL = true;
        sslCertificate = "/var/lib/acme/${nextcloudHostName}/cert.pem";
        sslCertificateKey = "/var/lib/acme/${nextcloudHostName}/key.pem";
        extraConfig = ''
          # Nextcloud uploads/downloads can be huge; stream them instead of
          # buffering them on the proxy.
          client_max_body_size 16G;
          client_body_buffer_size 512M;
          proxy_request_buffering off;
          proxy_buffering off;

          # Long running transfers and Nextcloud background operations.
          proxy_connect_timeout 60s;
          proxy_send_timeout 3600s;
          proxy_read_timeout 3600s;

          # Talk to the backend over HTTPS and verify its certificate.
          proxy_ssl_server_name on;
          proxy_ssl_verify on;
          proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;

          add_header Strict-Transport-Security "max-age=15552000; includeSubDomains" always;
        '';
        locations."/" = {
          proxyPass = nextcloudProxyPass;
          proxyWebsockets = true;
        };
      };
    };
  };

  systemd.services."${workloadService}" = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig.SupplementaryGroups = [ "acme" ];
  };
}
