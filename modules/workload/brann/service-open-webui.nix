{ lib, ... }:
let
  rootDomain = "raboes28.nl";
  workloadService = "open-webui";
  workloadServiceBindAddress = "127.0.0.1";
  workloadServicePort = 8080;
  workloadDomain = "brann.${rootDomain}";
  workloadUrl = "https://${workloadDomain}";
  # Name of the OAuth2 client in Kanidm, see ../heartstone/service-kanidm.nix.
  kanidmDomain = "idm.${rootDomain}";
  kanidmClientId = "openwebui";
  ollamaUrl = "https://ollama.${rootDomain}";
  # The default model of Hermes (khadgar). Using the same one means it is
  # usually already loaded in VRAM, so the first question of the day does not
  # wait for a model swap.
  defaultModel = "gemma4:12b";
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
  # The container evaluates its packages separately from the host. nixpkgs marks
  # Open WebUI as unfree (the "Open WebUI License" is BSD-3-Clause plus a
  # clause that requires keeping its branding), so allow exactly that package
  # instead of everything unfree.
  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "open-webui";

  users.users.nginx.extraGroups = [ "acme" ];

  services = {
    "${workloadService}" = {
      enable = true;
      host = workloadServiceBindAddress;
      port = workloadServicePort;
      openFirewall = false;
      # Setting `environment` replaces the module's defaults, so the telemetry
      # opt-outs it ships with are repeated here.
      environment = {
        SCARF_NO_ANALYTICS = "True";
        DO_NOT_TRACK = "True";
        ANONYMIZED_TELEMETRY = "False";

        # Always use the values below instead of whatever was last saved in the
        # Open WebUI database, so this file stays the single source of truth.
        # Edits in Admin Panel > Settings therefore do not survive a restart.
        # Users, chats, uploads and per-model access control live in the
        # database in their own tables and are not affected.
        ENABLE_PERSISTENT_CONFIG = "False";

        # Public URL. It has to be correct before the first SSO login.
        WEBUI_URL = workloadUrl;
        # Login over HTTPS only, so the session cookies get the Secure flag.
        WEBUI_SESSION_COOKIE_SECURE = "True";

        # Ollama on cho is the only model backend. The OpenAI connection is
        # turned off so Open WebUI does not try to reach api.openai.com.
        ENABLE_OLLAMA_API = "True";
        OLLAMA_BASE_URL = ollamaUrl;
        ENABLE_OPENAI_API = "False";
        DEFAULT_MODELS = defaultModel;

        # Login is Kanidm only: no local sign-up and no password form. Access is
        # decided by membership of the Kanidm group `openwebui-users`; anyone
        # who gets through Kanidm is a regular user without admin approval. The
        # first person to log in becomes the administrator.
        ENABLE_SIGNUP = "False";
        ENABLE_LOGIN_FORM = "False";
        ENABLE_PASSWORD_AUTH = "False";
        ENABLE_OAUTH_SIGNUP = "True";
        DEFAULT_USER_ROLE = "user";
        # Kanidm only releases an email claim for persons that have an email
        # address set, which is not provisioned here. Open WebUI would refuse
        # the login without one, so let it make up a placeholder address from
        # the stable Kanidm user id.
        ENABLE_OAUTH_EMAIL_FALLBACK = "True";
        # Users are matched by their Kanidm id, so an address added in Kanidm
        # later does not create a second account. It is only copied over a
        # placeholder at the next login when this is on.
        OAUTH_UPDATE_EMAIL_ON_LOGIN = "True";

        # Kanidm as OpenID Connect provider. This is a public client (PKCE, no
        # client secret), like Hermes on khadgar, so there is no secret to
        # create or store. The redirect URI has to match `originUrl` in
        # service-kanidm.nix exactly.
        OAUTH_PROVIDER_NAME = "Kanidm";
        OAUTH_CLIENT_ID = kanidmClientId;
        OPENID_PROVIDER_URL = "https://${kanidmDomain}/oauth2/openid/${kanidmClientId}/.well-known/openid-configuration";
        OPENID_REDIRECT_URI = "${workloadUrl}/oauth/oidc/callback";
        OAUTH_SCOPES = "openid email profile";
        OAUTH_CODE_CHALLENGE_METHOD = "S256";
        OAUTH_TOKEN_ENDPOINT_AUTH_METHOD = "none";

        # Keep the instance simple for non-technical users and keep data and
        # traffic inside the house: no calls home, no sharing with the Open
        # WebUI community, no arena models.
        ENABLE_VERSION_UPDATE_CHECK = "False";
        ENABLE_COMMUNITY_SHARING = "False";
        ENABLE_EVALUATION_ARENA_MODELS = "False";
        # The GPU is shared with Hermes and the Nextcloud Assistant. Chat titles
        # stay, but skip the extra model calls for tags and follow-up
        # questions after every answer.
        ENABLE_TAGS_GENERATION = "False";
        ENABLE_FOLLOW_UP_GENERATION = "False";

        # Web search is off by default in Open WebUI and has no engine until
        # one is set. DuckDuckGo needs no API key (so no secret in the Nix
        # store) and is bundled with Open WebUI. It scrapes results, so it can
        # be rate limited; keep the result count low to stay under that.
        ENABLE_WEB_SEARCH = "True";
        WEB_SEARCH_ENGINE = "duckduckgo";
        # Engines the DDGS library queries, tried in this order. The default
        # (`auto`) asks Wikipedia and Grokipedia first, which is a poor fit for
        # live questions like the weather. With one request at a time (below),
        # later engines are only used when an earlier one fails or is rate
        # limited.
        DDGS_BACKEND = "duckduckgo,brave,yahoo,mojeek,yandex";
        WEB_SEARCH_RESULT_COUNT = "5";
        WEB_SEARCH_CONCURRENT_REQUESTS = "1";
        # Use only the snippets DuckDuckGo returns instead of fetching every
        # result page, and hand them to the model directly instead of chunking
        # and embedding them first. This is faster, needs no embedding model
        # for searches and keeps the prompt small, at the cost of less detail
        # per result.
        BYPASS_WEB_SEARCH_WEB_LOADER = "True";
        BYPASS_WEB_SEARCH_EMBEDDING_AND_RETRIEVAL = "True";
        # Code interpreter is enabled by default in Open WebUI. The engine is
        # Pyodide, which runs the code in the user's browser instead of on the
        # server, so nothing from a chat executes inside brann-1.
        ENABLE_CODE_INTERPRETER = "True";
        CODE_INTERPRETER_ENGINE = "pyodide";
        # Default system prompt for every model. A small local model loops on
        # empty search results (rewording the same query many times), so the
        # prompt caps retries, forbids answering live facts from memory and
        # asks for an honest "could not verify" instead of invented numbers.
        # A model with its own system prompt in Admin Panel > Models keeps that.
        DEFAULT_MODEL_PARAMS = builtins.toJSON {
          # Native tool calling: the model picks and chains tools (search, fetch)
          # itself instead of Open WebUI's older prompt-based routing. This is
          # already the default in current Open WebUI; set explicitly so an
          # upgrade cannot change it silently.
          function_calling = "native";
          system = ''
            You are a helpful assistant for a household. Answer in the user's language, concisely and plainly.

            Facts and freshness
            - Never answer from memory for anything that changes: weather, news, prices, schedules, versions, sports, "latest" or "current" anything. Use the tools.
            - Use the date and time given by the system to judge whether a result is current.

            Using web search
            - Search at most 2 times per question, with a short keyword query (for example "Sacramento weather"). Never repeat or just reword a query that returned nothing.
            - If a promising page is found but its snippet lacks the answer, fetch that one page. If the page is empty or has no figures, try a different source once, then stop.
            - For weather, prefer a data source (Open-Meteo) over searching, if that tool is available.

            Answering
            - Give the answer first, then a short source line with the link.
            - State the time or date of the data when it matters.
            - If you could not find or verify something, say exactly what you tried and what is missing. Never invent numbers, quotes or links.
            - Do not narrate retry attempts or apologise at length; keep it short.
          '';
        };
        # Switch the web search and code interpreter toggles on by default in
        # every new chat. Users can still turn them off per chat. A model that
        # was given its own settings in Admin Panel > Models keeps those instead.
        DEFAULT_MODEL_METADATA = builtins.toJSON {
          capabilities = {
            web_search = true;
            code_interpreter = true;
          };
          defaultFeatureIds = [
            "web_search"
            "code_interpreter"
          ];
        };
      };
    };

    nginx = {
      enable = true;
      user = "nginx";
      group = "nginx";
      # Passes Host and X-Forwarded-* on, which Open WebUI needs to build the
      # right SSO redirect URL behind the proxy.
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      # Answers can stream for a long time on a model that is partly on the CPU.
      proxyTimeout = "3600s";
      # Allow document uploads for chats with files.
      clientMaxBodySize = "100m";
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
          # Open WebUI uses websockets for live updates and streaming.
          locations."/".proxyWebsockets = true;
          # Send tokens to the browser as they are generated instead of
          # buffering the whole answer.
          locations."/".extraConfig = ''
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
