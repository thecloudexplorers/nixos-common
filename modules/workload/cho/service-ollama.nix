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
      environmentVariables = {
        OLLAMA_KEEP_ALIVE = "20m";
        # Ollama's OpenAI compatible endpoint ignores the context size a client
        # configures and falls back to its own default (4k on a small GPU). Hermes
        # alone sends a larger system prompt and tool list than that, so the
        # conversation history was cut off and follow-up questions lost their
        # context. Keep this equal to context_length in khadgar's
        # service-hermes-agent.nix.
        OLLAMA_CONTEXT_LENGTH = "65536";
        # Flash attention is required for a quantized KV cache and lowers memory
        # use at long context sizes.
        OLLAMA_FLASH_ATTENTION = "1";
        # Store the KV cache as q8_0 instead of f16. This roughly halves its VRAM
        # use at a 64k context with little quality loss, so more of each model
        # stays on the 16 GB GPU instead of being offloaded to the CPU.
        OLLAMA_KV_CACHE_TYPE = "q8_0";
        # Keep 1 GiB of VRAM free per GPU (value in bytes). Ollama packs a model
        # and its 64k context almost to the brim, and the runner then failed on
        # its first request: cublasCreate could not allocate its handle
        # ("CUDA error: the resource allocation failed"). The headroom is
        # for cuBLAS and the compute buffers that the estimate does not count.
        OLLAMA_GPU_OVERHEAD = "1073741824";
      };
      # Every model listed here is downloaded and can be selected per request
      # through the "model" field. Ollama loads one on demand and unloads idle ones.
      loadModels = [
        # Coding (PowerShell, Bicep) and agentic work.
        "qwen3.6:35b"
        "laguna-xs-2.1"
        # Architecture documents and writing; default model of Hermes (khadgar)
        # and the Nextcloud Assistant (dalaran).
        "gemma4:26b"
        # Small and fast; simple chat.
        "gemma4:e4b"
        # Small and fast model that Hermes (khadgar) can switch to.
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
