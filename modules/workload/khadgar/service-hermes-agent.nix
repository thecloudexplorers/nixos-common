{ pkgs, inputs, ... }:
let
  rootDomain = "raboes28.nl";
  workloadName = "khadgar";
  workloadService = "hermes-agent";
  workloadServiceUser = "hermes";
  workloadServicePath = "/var/lib/hermes";
  workloadServiceBindAddress = "127.0.0.1";
  workloadServicePort = 9119;
  workloadServiceApiPort = 8642;
  workloadServiceA2aPort = 9900;
  workloadDomain = "${workloadName}.${rootDomain}";
  # Ollama on cho-1 is the primary model backend; it is OpenAI compatible.
  workloadServiceCustomBaseUrl = "https://ollama.${rootDomain}/v1";
  workloadServiceDefaultContextLength = 65536;
  # Secrets file, bind mounted read-only from the host (see container-1.nix).
  workloadServiceEnvironmentFile = "/tmp/${workloadName}-hermes/hermes.env";
  chromiumCdpBindAddress = "127.0.0.1";
  chromiumCdpBindPort = 9222;
  # The proxies listen on their own ports, so they do not clash with each other.
  proxyPort = 9120;
  proxyApiPort = 8643;
  proxyA2aPort = 9901;
  proxyPublicUrl = "https://${workloadDomain}:${toString proxyPort}";
  proxyA2aPublicUrl = "https://${workloadDomain}:${toString proxyA2aPort}";
  mkProxyListeners =
    port:
    map
      (addr: {
        inherit addr port;
        ssl = true;
      })
      [
        "0.0.0.0"
        "[::]"
      ];
  proxyListeners = mkProxyListeners proxyPort;
  proxyApiListeners = mkProxyListeners proxyApiPort;
  proxyA2aListeners = mkProxyListeners proxyA2aPort;
  mkProxyHost = listen: upstreamPort: {
    serverName = workloadDomain;
    onlySSL = true;
    http2 = true;
    sslCertificate = "/var/lib/acme/${workloadDomain}/fullchain.pem";
    sslCertificateKey = "/var/lib/acme/${workloadDomain}/key.pem";
    inherit listen;
    locations."/" = {
      proxyPass = "http://${workloadServiceBindAddress}:${toString upstreamPort}";
      proxyWebsockets = true;
      # Pass the public hostname on: Hermes only accepts the hostname of its
      # configured public_url (DNS rebinding protection).
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
      '';
    };
  };
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  users.users.nginx.extraGroups = [ "acme" ];

  services = {
    "${workloadService}" = {
      enable = true;
      # The container itself is the sandbox; Hermes' own container mode is not needed.
      container.enable = false;
      user = workloadServiceUser;
      group = workloadServiceUser;
      stateDir = workloadServicePath;
      workingDirectory = "${workloadServicePath}/workspace";
      restart = "always";
      # Makes the `hermes` command available for administration in the container.
      addToSystemPackages = true;
      # Secrets (never in the Nix store). Expected variables, see the README:
      #   MISTRAL_API_KEY                         fallback model provider
      #   API_SERVER_KEY                          enables and protects the API server
      #   A2A_BEARER_TOKEN                        protects the A2A endpoint
      #   HERMES_DASHBOARD_BASIC_AUTH_USERNAME    dashboard login
      #   HERMES_DASHBOARD_BASIC_AUTH_PASSWORD
      #   HERMES_DASHBOARD_BASIC_AUTH_SECRET      session signing secret
      environmentFiles = [ workloadServiceEnvironmentFile ];
      environment = {
        # API server: it is only enabled when API_SERVER_KEY is set, so it can
        # never run unauthenticated. The proxy exposes it to the LAN.
        API_SERVER_HOST = workloadServiceBindAddress;
        API_SERVER_PORT = toString workloadServiceApiPort;
        API_SERVER_MODEL_NAME = "hermes-agent";
        # Agent-to-agent endpoint. Without A2A_BEARER_TOKEN Hermes treats every
        # caller as local, which would include the proxy, so the token is required.
        A2A_PORT = toString workloadServiceA2aPort;
        A2A_AGENT_NAME = "Khadgar";
        A2A_PUBLIC_URL = proxyA2aPublicUrl;
        # The browser tool drives the Chromium from nixpkgs.
        AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.ungoogled-chromium}/bin/chromium";
      };
      # Native tools used by the browser, voice and media features.
      extraPackages = with pkgs; [
        agent-browser
        ffmpeg
        openssl
        portaudio
        ungoogled-chromium
      ];
      # Optional Hermes features from its pyproject.toml, built into the venv.
      extraDependencyGroups = [
        "messaging"
        "voice"
        "edge-tts"
        "piper"
      ];
      # The web dashboard shares the process with the backend. Binding it to
      # loopback keeps it behind the nginx proxy below.
      backend = {
        mode = "dashboard";
        host = workloadServiceBindAddress;
        port = workloadServicePort;
      };
      settings = {
        timezone = "Europe/Amsterdam";
        model = {
          default = "qwen3.5:9b-q8_0";
          provider = "custom";
          base_url = workloadServiceCustomBaseUrl;
          context_length = workloadServiceDefaultContextLength;
        };
        # Used when the Ollama endpoint fails.
        fallback_providers = [
          {
            provider = "custom";
            base_url = "https://api.mistral.ai/v1";
            key_env = "MISTRAL_API_KEY";
            model = "mistral-small-2603";
          }
        ];
        toolsets = [
          "hermes-cli"
          "a2a"
          "browser"
          "clarify"
          "code_execution"
          "cronjob"
          "delegation"
          "file"
          "memory"
          "messaging"
          "session_search"
          "skills"
          "todo"
          "tts"
          "web"
        ];
        agent = {
          max_turns = 150;
          gateway_timeout = 1800;
        };
        terminal.backend = "local";
        browser.cdp_url = "http://${chromiumCdpBindAddress}:${toString chromiumCdpBindPort}";
        # A non-loopback public_url switches on the login gate of the dashboard
        # (credentials come from the environment file) and makes Hermes accept
        # the proxy's hostname. Sessions expire after 15 minutes.
        dashboard = {
          public_url = proxyPublicUrl;
          basic_auth.session_ttl_seconds = 900;
        };
        display = {
          personality = "helpful";
          show_reasoning = true;
          streaming = true;
          timestamps = true;
        };
        streaming.enabled = true;
        memory = {
          memory_enabled = true;
          user_profile_enabled = true;
        };
        # Local text-to-speech and speech-to-text, no cloud service involved.
        tts.provider = "piper";
        stt = {
          enabled = true;
          provider = "local";
        };
      };
    };

    nginx = {
      enable = true;
      user = "nginx";
      group = "nginx";
      recommendedProxySettings = false;
      recommendedTlsSettings = true;
      proxyTimeout = "3600s";
      enableReload = true;
      serverTokens = false;
      virtualHosts = {
        # Requests that do not use the right hostname are dropped on every port.
        "default" = {
          serverName = "localhost";
          default = true;
          onlySSL = true;
          sslCertificate = "/var/lib/acme/${workloadDomain}/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/${workloadDomain}/key.pem";
          locations."/".return = "444";
          listen = proxyListeners ++ proxyApiListeners ++ proxyA2aListeners;
        };
        "${workloadDomain}" = mkProxyHost proxyListeners workloadServicePort;
        "${workloadDomain}-api" = mkProxyHost proxyApiListeners workloadServiceApiPort;
        "${workloadDomain}-a2a" = mkProxyHost proxyA2aListeners workloadServiceA2aPort;
      };
    };
  };

  # Headless Chromium for the browser tool. Hermes attaches to it over the
  # Chrome DevTools Protocol, which is bound to loopback only.
  systemd.services.chromium-cdp = {
    description = "Headless Chromium with CDP for Hermes Agent";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    environment.HOME = "${workloadServicePath}/chrome-debug";
    serviceConfig = {
      User = workloadServiceUser;
      # The container is the sandbox: Chromium's own sandbox needs user
      # namespaces, which are not available inside it.
      ExecStart = ''
        ${pkgs.ungoogled-chromium}/bin/chromium \
          --headless=new \
          --remote-debugging-port=${toString chromiumCdpBindPort} \
          --remote-debugging-address=${chromiumCdpBindAddress} \
          --user-data-dir=${workloadServicePath}/chrome-debug \
          --no-first-run \
          --no-default-browser-check \
          --disable-gpu \
          --no-sandbox
      '';
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # The browser profile lives in the persistent state directory.
  systemd.tmpfiles.rules = [
    "d ${workloadServicePath}/chrome-debug 0700 ${workloadServiceUser} ${workloadServiceUser} -"
  ];

  # The read-only certificate is shared with medivh's ACME container.
  systemd.services.nginx.serviceConfig.SupplementaryGroups = [ "acme" ];
}
