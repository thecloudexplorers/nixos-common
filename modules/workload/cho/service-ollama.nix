{ pkgs, ... }:
let
  rootDomain = "raboes28.nl";
  workloadName = "cho";
  workloadService = "ollama";
  workloadServiceUser = workloadService;
  workloadServiceGroup = workloadServiceUser;
  workloadServicePath = "/var/lib/ollama";
  workloadServiceModelsPath = "${workloadServicePath}/models";
  workloadServiceBindAddress = "127.0.0.1";
  workloadServicePort = 11434;
  workloadDomain = "ollama.${rootDomain}";
  proxyPort = 443;
  proxyListeners = [
    {
      addr = "0.0.0.0";
      port = proxyPort;
      ssl = true;
    }
    {
      addr = "[::]";
      port = proxyPort;
      ssl = true;
    }
  ];
  proxyPass = "http://${workloadServiceBindAddress}:${toString workloadServicePort}";
in
{
  users.users.nginx.extraGroups = [ "acme" ];

  services = {
    "${workloadService}" = {
      enable = true;
      # CUDA build so Ollama uses the NVIDIA GPU passed into the container.
      package = pkgs.ollama-cuda;
      user = workloadServiceUser;
      group = workloadServiceGroup;
      home = workloadServicePath;
      models = workloadServiceModelsPath;
      host = workloadServiceBindAddress;
      port = workloadServicePort;
      openFirewall = false;
      # Keep a model in VRAM for 60 minutes after the last request instead of the
      # 5 minute default, so repeated use does not pay the model load time again.
      environmentVariables.OLLAMA_KEEP_ALIVE = "60m";
      # Every model listed here is downloaded and can be selected per request
      # through the "model" field. Ollama loads one on demand and unloads idle ones.
      loadModels = [
        "mistral-small:latest"
        "ministral-3:14b"
        # "qwen3.5:9b" # Q4, ~7 GB; replaced by the Q8 variant below
        "qwen3.5:9b-q8_0"
      ];
      syncModels = true;
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
        "default" = {
          serverName = "localhost";
          default = true;
          forceSSL = true;
          sslCertificate = "/var/lib/acme/${workloadDomain}/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/${workloadDomain}/key.pem";
          locations."/".return = "444";
          listen = proxyListeners;
        };
        "${workloadDomain}" = {
          serverName = workloadDomain;
          forceSSL = true;
          sslCertificate = "/var/lib/acme/${workloadDomain}/fullchain.pem";
          sslCertificateKey = "/var/lib/acme/${workloadDomain}/key.pem";
          locations."/".proxyPass = proxyPass;
          locations."/".proxyWebsockets = true;
          locations."/".extraConfig = ''
            proxy_set_header Host localhost:${toString workloadServicePort};
            proxy_buffering off;
          '';
          listen = proxyListeners;
        };
      };
    };
  };

  # The read-only certificate is shared with medivh's ACME container.
  systemd.services.nginx.serviceConfig.SupplementaryGroups = [ "acme" ];
}
