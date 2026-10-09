{ lib, pkgs, ... }:
let
  workloadService = "kanidm";
  rootDomain = "raboes28.nl";
  serviceDomain = "idm.${rootDomain}";
  nextcloudHostName = "nextcloud.${rootDomain}";
  # Hermes Agent dashboard (khadgar workload). It listens on its own port.
  hermesHostName = "khadgar.${rootDomain}";
  hermesDashboardUrl = "https://${hermesHostName}:9120";
  # Open WebUI (brann workload), served on the default HTTPS port.
  openWebuiHostName = "brann.${rootDomain}";
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
      provision = {
        enable = true;

        # Declarative Kanidm identities.
        # Add or remove entries here, then deploy with nixos-rebuild.
        groups = {
          faml-users = { };
          kids-users = { };
          test-users = { };
          # Members allowed to authenticate to Nextcloud via OIDC. See
          # ../dalaran/service-nextcloud.nix for the client side of
          # this integration.
          nextcloud-users = {
            members = [
              "marlous"
              "peon"
              "jev"
              "lyov"
            ];
          };
          # Members allowed to log in to the Hermes Agent dashboard. Hermes can
          # run code and use tools, so only add people who should have that.
          # See ../khadgar/service-hermes-agent.nix for the client side.
          hermes-users = {
            members = [ "jev" ];
          };
          # Members allowed to log in to Open WebUI, the chat interface for
          # the local models. See ../brann/service-open-webui.nix for the
          # client side.
          openwebui-users = {
            members = [
              "jev"
              "marlous"
            ];
          };
        };
        persons = {
          marlous = {
            displayName = "Marlous";
            mailAddresses = [ "marlous@raboes28.nl" ];
            groups = [ "faml-users" ];
          };
          peon = {
            displayName = "Peon";
            mailAddresses = [ "peon@raboes28.nl" ];
            groups = [ "test-users" ];
          };
          jev = {
            displayName = "Jev";
            # Released as the `email` claim to the OIDC clients (Open WebUI,
            # Nextcloud). Nothing sends mail to it, so it only has to be a
            # valid, unique address.
            mailAddresses = [ "jev@raboes28.nl" ];
            groups = [ "faml-users" ];
          };
          lyov = {
            displayName = "Lyov";
            mailAddresses = [ "lyov@raboes28.nl" ];
            groups = [ "kids-users" ];
          };
        };

        # OAuth2/OIDC resource servers. Nextcloud's `user_oidc` app is
        # configured as the client, see
        # ../dalaran/service-nextcloud.nix and
        # docs/nextcloud-kanidm-sso.md.
        systems.oauth2.nextcloud = {
          displayName = "Nextcloud";
          # Landing page shown from the Kanidm application portal.
          originLanding = "https://${nextcloudHostName}/";
          # Must exactly match the callback registered by the Nextcloud
          # `user_oidc` app.
          originUrl = "https://${nextcloudHostName}/apps/user_oidc/code";
          # `basicSecretFile` is intentionally left unset: kanidm generates a
          # random client secret on its own, which is retrieved once via
          # `kanidm system oauth2 show-basic-secret nextcloud` and stored as
          # a host-managed secret for Nextcloud (see docs/nextcloud-kanidm-sso.md).
          # `openid` is mandatory for OIDC clients to function at all.
          scopeMaps.nextcloud-users = [
            "openid"
            "profile"
            "email"
          ];
          # Use the short Kanidm username (e.g. "marlous") instead of the
          # full SPN (e.g. "marlous@idm.raboes28.nl") as preferred_username.
          preferShortUsername = true;
        };

        # Hermes Agent dashboard login. Hermes' generic OIDC provider is a
        # public client: it uses PKCE and has no client secret, so no secret
        # has to be fetched or stored on the host.
        systems.oauth2.hermes = {
          displayName = "Hermes Agent";
          public = true;
          # Landing page shown from the Kanidm application portal.
          originLanding = "${hermesDashboardUrl}/";
          # Hermes sends <dashboard.public_url>/auth/callback as redirect URI.
          originUrl = "${hermesDashboardUrl}/auth/callback";
          # `openid` is mandatory for OIDC clients to function at all.
          scopeMaps.hermes-users = [
            "openid"
            "profile"
            "email"
          ];
          preferShortUsername = true;
        };

        # Open WebUI login. Like Hermes this is a public client (PKCE, no client
        # secret), so no secret has to be fetched or stored on the host.
        systems.oauth2.openwebui = {
          displayName = "Open WebUI";
          public = true;
          # Landing page shown from the Kanidm application portal.
          originLanding = "https://${openWebuiHostName}/";
          # Must exactly match OPENID_REDIRECT_URI in
          # ../brann/service-open-webui.nix.
          originUrl = "https://${openWebuiHostName}/oauth/oidc/callback";
          # `openid` is mandatory for OIDC clients to function at all.
          scopeMaps.openwebui-users = [
            "openid"
            "profile"
            "email"
          ];
          preferShortUsername = true;
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
