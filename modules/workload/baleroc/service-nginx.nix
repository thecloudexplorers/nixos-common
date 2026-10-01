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
  # Stable SLAAC (EUI-64) address derived from dalaran-1's MAC.
  dalaranAddressIPv6 = "2a02:a441:f08f:0:781e:46ff:feb4:6f11";
  nextcloudProxyPass = "https://${nextcloudHostName}";
  idmHostName = "idm.${rootDomain}";
  idmProxyPass = "https://${idmHostName}";
  # Heartstone-1's LAN IP, set via a DHCP reservation on the router (MAC
  # c2:51:cd:8e:23:01). Same static hosts entry approach as for dalaran.
  heartstoneAddressIPv4 = "192.168.1.209";
  # Stable SLAAC (EUI-64) address derived from heartstone-1's MAC.
  heartstoneAddressIPv6 = "2a02:a441:f08f:0:c051:cdff:fe8e:2301";
in
{
  # Grant nginx read/traverse access to the ACME-managed certificate
  # directory (gid 966, shared across all containers in this repo via
  # modules/users/users/workloads/acme.nix).
  users.users."${workloadServiceUser}".extraGroups = [ "acme" ];

  networking.extraHosts = ''
    ${dalaranAddressIPv4} ${nextcloudHostName}
    ${dalaranAddressIPv6} ${nextcloudHostName}
    ${heartstoneAddressIPv4} ${idmHostName}
    ${heartstoneAddressIPv6} ${idmHostName}
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
    # Per client IP request limit for the identity provider, which is a
    # sensitive public endpoint (credential stuffing / brute force).
    appendHttpConfig = ''
      limit_req_zone $binary_remote_addr zone=idm:10m rate=10r/s;
      limit_req_status 429;
    '';
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
        sslCertificate = "/var/lib/acme/${nextcloudHostName}/fullchain.pem";
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
          # The Let's Encrypt chain is 4 certificates deep (leaf, intermediate,
          # cross-signed root, ISRG Root X2); nginx defaults to a depth of 1.
          proxy_ssl_verify_depth 5;
          proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;

          add_header Strict-Transport-Security "max-age=15552000; includeSubDomains" always;
        '';
        locations."/" = {
          proxyPass = nextcloudProxyPass;
          proxyWebsockets = true;
        };
      };
      "${idmHostName}" = {
        serverName = idmHostName;
        forceSSL = true;
        sslCertificate = "/var/lib/acme/${idmHostName}/fullchain.pem";
        sslCertificateKey = "/var/lib/acme/${idmHostName}/key.pem";
        extraConfig = ''
          limit_req zone=idm burst=30 nodelay;

          # Talk to the backend over HTTPS and verify its certificate.
          proxy_ssl_server_name on;
          proxy_ssl_verify on;
          proxy_ssl_verify_depth 5;
          proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;

          add_header Strict-Transport-Security "max-age=15552000; includeSubDomains" always;
        '';
        locations."/".proxyPass = idmProxyPass;
      };
    };
  };

  systemd.services."${workloadService}" = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig.SupplementaryGroups = [ "acme" ];
  };
}
