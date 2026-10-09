# khadgar

Hermes Agent (AI agent with web dashboard, OpenAI compatible API server and
A2A endpoint) and HTTPS reverse proxies (container `khadgar-1`).

## Access

| Service   | URL                                   | Auth                                      |
| --------- | ------------------------------------- | ----------------------------------------- |
| Dashboard | `https://khadgar.raboes28.nl:9120`    | Kanidm login (members of `hermes-users`)  |
| API       | `https://khadgar.raboes28.nl:8643/v1` | `Authorization: Bearer $API_SERVER_KEY`   |
| A2A       | `https://khadgar.raboes28.nl:9901`    | `Authorization: Bearer $A2A_BEARER_TOKEN` |

- Hermes itself listens only on `127.0.0.1` (`9119`, `8642`, `9900`); the
  container firewall opens only the proxy ports `9120`, `8643` and `9901`.
- Served directly by `khadgar-1`, not through Baleroc. Keep these ports on your
  LAN/VPN and do not forward them from the internet.
- The router needs a DHCP reservation for MAC `02:6f:7f:e5:6e:70`. Point the LAN
  DNS records (A and AAAA) for `khadgar.raboes28.nl` at that reserved address.
- The certificate must exist before the container can serve HTTPS: let
  [medivh](../medivh/README.md) issue it first
  (`systemctl start acme-khadgar.raboes28.nl.service` in `medivh-1`), then
  restart `khadgar-1`.
- The dashboard login is Kanidm SSO. The OAuth2 client `hermes` and the group
  `hermes-users` are defined in
  [service-kanidm.nix](../heartstone/service-kanidm.nix); add members there to
  give someone access. It is a public client (PKCE, no client secret), so no
  secret has to be created. `khadgar-1` must be able to resolve and reach
  `idm.raboes28.nl` because Hermes does OIDC discovery from inside the
  container itself before it redirects back to the dashboard; the static LAN
  host entry in [container-1/networking-1.nix](container-1/networking-1.nix)
  keeps that private IdP backend stable even though the public route is through
  the router and proxy stack. Deploy the Kanidm change before opening the
  dashboard.

## Secrets (you create these, they never go in Nix)

Create `/mnt/ssd/khadgar/1/secrets/hermes/hermes.env` on the host (the directory
is created by `host-data.nix`, mode `0700 root root`). One `KEY=value` per line.
The dashboard login needs no secret here (see Access).

```bash
sudo tee /mnt/ssd/khadgar/1/secrets/hermes/hermes.env >/dev/null <<EOF
API_SERVER_KEY=$(openssl rand -base64 32)
A2A_BEARER_TOKEN=$(openssl rand -base64 32)
EOF
sudo chmod 600 /mnt/ssd/khadgar/1/secrets/hermes/hermes.env
```

- `API_SERVER_KEY`: without a key (at least 16 characters) the API server does
  not start, so it can never run unauthenticated.
- `A2A_BEARER_TOKEN`: required. Without it Hermes treats every caller as local,
  and the proxy would expose A2A to the LAN without authentication.
- Hermes only reads this file when the container is activated: the module
  merges it into the Hermes state `.env` at container start (and on a system
  switch), not when a service restarts. After creating or changing it, restart
  the container: `sudo nixos-container restart khadgar-1`. Restarting only the
  Hermes services keeps the old values.

## Handy commands

Run on the host.

```bash
# Shell / logs
sudo nixos-container root-login khadgar-1
sudo nixos-container run khadgar-1 -- journalctl -u hermes-agent.service -f
sudo nixos-container run khadgar-1 -- journalctl -u hermes-backend.service -f
sudo nixos-container run khadgar-1 -- journalctl -u nginx.service -f
sudo nixos-container run khadgar-1 -- journalctl -u chromium-cdp.service -f

# Check the endpoints and certificate
curl -sS https://khadgar.raboes28.nl:8643/v1/models -H "Authorization: Bearer <API_SERVER_KEY>"
echo | openssl s_client -connect khadgar.raboes28.nl:9120 -servername khadgar.raboes28.nl 2>/dev/null | openssl x509 -noout -dates -subject

# Container lifecycle (avoid unless recovering)
sudo nixos-container restart khadgar-1
```

## What runs here

- Hermes Agent comes from the `hermes-agent` flake input (see
  [flake.nix](../../../flake.nix)) and is configured through
  [service-hermes-agent.nix](service-hermes-agent.nix). The Hermes container
  mode is off; this NixOS container is the sandbox.
- Models: Ollama on [cho](../cho/README.md) (`https://ollama.raboes28.nl/v1`,
  `gemma4:26b` by default, 64k context) is the only model backend. The
  named provider `ollama` also lists `qwen3.6:35b`, `laguna-xs-2.1`,
  `gemma4:e4b` and `qwen3.5:9b-q8_0`; switch in a session with
  `/model custom:ollama:<model>`. Keep that list in sync with cho's
  `loadModels`. There is no cloud
  fallback. `khadgar-1` resolves `ollama.raboes28.nl` through a static host
  entry in [container-1/networking-1.nix](container-1/networking-1.nix), like
  the IdP; without it model requests fail with "Connection error" and Hermes
  then tries a runtime-configured fallback provider and reports a misleading
  "401 Invalid API Key". Hermes needs a large context window;
  check on the host with `sudo nixos-container run cho-1 -- ollama ps` that the
  loaded model has the context you expect.
- Nginx terminates TLS using the certificate from medivh and proxies each port
  to the matching local Hermes port, passing the public hostname on (Hermes
  rejects other `Host` headers).
- `chromium-cdp.service` runs headless Chromium on `127.0.0.1:9222` for the
  browser tool.
- Voice: local Piper text-to-speech and local Whisper speech-to-text. Models are
  downloaded on first use, so the container needs internet access.
- There is no web search backend configured: the example this was based on used a
  SearXNG instance, which does not exist in this repository.

## Persistent data

- `/mnt/ssd/khadgar/1/var/lib/hermes` stores the Hermes state: configuration,
  sessions, memory, workspace and the Chromium profile. It is owned by uid/gid
  `567`.
- `/mnt/ssd/khadgar/1/secrets/hermes` holds `hermes.env` (read-only in the
  container at `/tmp/khadgar-hermes`).
- `/mnt/ssd/medivh/1/var/lib/acme/khadgar.raboes28.nl` provides the read-only
  TLS certificate.
