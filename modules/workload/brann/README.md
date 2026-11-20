# brann

Open WebUI, a simple chat interface for the local models on Ollama, with an
HTTPS reverse proxy (container `brann-1`). Meant for people who just want to
chat, as opposed to [khadgar](../khadgar/README.md) (Hermes Agent, an agent
with tools).

## Access

| Service    | URL                         | Auth                                        |
| ---------- | --------------------------- | ------------------------------------------- |
| Open WebUI | `https://brann.raboes28.nl` | Kanidm login (members of `openwebui-users`) |

- Open WebUI itself listens only on `127.0.0.1:8080`; the container firewall
  opens only `443`, served by nginx.
- Reached from the internet through [Baleroc](../baleroc/README.md), which
  terminates TLS for `brann.raboes28.nl` and proxies to `brann-1` over HTTPS
  (the vhost and the static host entry for `brann-1` are in
  [../baleroc/service-nginx.nix](../baleroc/service-nginx.nix)). `brann-1` still
  serves HTTPS itself, so LAN clients can reach it directly. Do not forward
  port 443 to `brann-1` itself; forward it to Baleroc only.
- The router needs a DHCP reservation for MAC `02:b4:a1:7e:3c:5d`. Point the LAN
  DNS records (A and AAAA) for `brann.raboes28.nl` at that reserved address, and
  the public DNS records at the router's public address (which forwards to
  Baleroc). If the reserved address changes, update it in
  [../baleroc/service-nginx.nix](../baleroc/service-nginx.nix) too.
- The certificate must exist before nginx can serve HTTPS: let
  [medivh](../medivh/README.md) issue it first
  (`systemctl start acme-brann.raboes28.nl.service` in `medivh-1`), then
  restart `brann-1`.
- Login is Kanidm SSO only; there is no local sign-up or password form. The
  OAuth2 client `openwebui` and the group `openwebui-users` are defined in
  [service-kanidm.nix](../heartstone/service-kanidm.nix); add members there to
  give someone access. It is a public client (PKCE, no client secret), so no
  secret has to be created. `brann-1` must be able to reach `idm.raboes28.nl`
  from inside the container (OIDC discovery), which the static LAN host entry in
  [container-1/networking-1.nix](container-1/networking-1.nix) takes care of.
  Deploy the Kanidm change before the first login.
- The first person to log in becomes the Open WebUI administrator; everyone
  after that is a regular user. Kanidm persons have an email address
  (`mailAddresses` in [service-kanidm.nix](../heartstone/service-kanidm.nix));
  a person without one gets a generated placeholder address.

## Secrets

None. Open WebUI generates the key that signs login sessions on first start and
keeps it in its state directory, and the SSO client is public.

## Deploy order

1. Deploy (rebuild the host) with the Kanidm, medivh and brann changes.
2. Add the DHCP reservation and the DNS records for `brann.raboes28.nl`.
3. Issue the certificate in `medivh-1` (see above), then restart `brann-1`.
4. Open `https://brann.raboes28.nl` and log in with Kanidm.

## Handy commands

Run on the host.

```bash
# Shell / logs
sudo nixos-container root-login brann-1
sudo nixos-container run brann-1 -- journalctl -u open-webui.service -f
sudo nixos-container run brann-1 -- journalctl -u nginx.service -f

# Check the certificate
echo | openssl s_client -connect brann.raboes28.nl:443 -servername brann.raboes28.nl 2>/dev/null | openssl x509 -noout -dates -subject

# Container lifecycle (avoid unless recovering)
sudo nixos-container restart brann-1
```

## What runs here

- Open WebUI is the nixpkgs `services.open-webui` module, configured through
  [service-open-webui.nix](service-open-webui.nix).
- Models: Ollama on [cho](../cho/README.md) (`https://ollama.raboes28.nl`) is the
  only backend; the OpenAI connection is off. `gemma4:12b` is the default, like
  for Hermes, so it is usually already loaded.
  `brann-1` resolves `ollama.raboes28.nl` through a static host entry in
  [container-1/networking-1.nix](container-1/networking-1.nix).
- The GPU is shared with Hermes and the Nextcloud Assistant. Ollama keeps one
  large model loaded at a time, so a request for a different model waits for a
  swap. Tags and follow-up question generation are off to avoid extra model
  calls.
- Settings from Nix always win: `ENABLE_PERSISTENT_CONFIG` is off, so changes
  made in Admin Panel > Settings are lost when the service restarts. Change them
  in the Nix file instead. Users, chats, uploads and per-model access control
  are stored in the database and persist.
- Which models non-technical users see is set per model in Admin Panel >
  Models (access control), for example to show only `gemma4:e4b` and
  `gemma4:26b`. This is stored in the database, so it persists.
- Nginx terminates TLS using the certificate from medivh and proxies to
  `127.0.0.1:8080`, including websockets and without buffering so answers
  stream.
- Web search uses DuckDuckGo (no API key, so no secret) through the DDGS
  library, which tries `duckduckgo,brave,bing,google,yahoo,mojeek` in that order
  (`DDGS_BACKEND`) and skips the encyclopedia engines of the `auto` default. It is switched on by
  default in every new chat (`DEFAULT_MODEL_METADATA`); users can turn it off
  with the web search toggle in the message box. DuckDuckGo can rate
  limit scraping, so the result count is 3 and requests run one at a time; if
  that becomes a problem, run a SearXNG workload and switch
  `WEB_SEARCH_ENGINE` to `searxng`. Both the web loader and the embedding and
  retrieval step are bypassed: the model gets only the search result snippets,
  which is fast but less detailed than full pages. `brann-1` needs internet
  access to reach DuckDuckGo.
- Every model gets a default system prompt and native tool calling
  (`DEFAULT_MODEL_PARAMS`, `function_calling = "native"`, already the Open WebUI
  default). The prompt caps
  web searches at two per question, forbids answering live facts from memory
  and asks for an honest "could not verify" instead of invented numbers. A
  system prompt set per model in Admin Panel > Models overrides it. Open WebUI
  keeps `DEFAULT_MODEL_PARAMS` in its database once changed in the admin UI, and
  that stored value then wins over the Nix setting.
- The code interpreter is on by default in every new chat
  (`DEFAULT_MODEL_METADATA`) and uses Pyodide, so code runs in the user's
  browser, not on the server. Users can turn it off per chat.
- Open WebUI downloads a small embedding model from Hugging Face the first
  time a document is uploaded, so the container needs internet access.

## Persistent data

- `/mnt/ssd/brann/1/var/lib/open-webui` stores the database (users, chats),
  uploads, the session signing key and caches. It is mounted at
  `/var/lib/private/open-webui` because the service runs as a systemd
  `DynamicUser`; systemd changes the ownership itself when the service starts.
- `/mnt/ssd/medivh/1/var/lib/acme/brann.raboes28.nl` provides the read-only TLS
  certificate.
