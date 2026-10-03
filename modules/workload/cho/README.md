# cho

Ollama model server and HTTPS reverse proxy (container `cho-1`).

## Access

- API endpoint: `https://ollama.raboes28.nl` (HTTPS on port `443`)
- Ollama listens only on `127.0.0.1:11434`; the container firewall opens only
  the HTTPS proxy port, `443`.
- The API has no user authentication. Keep this endpoint on your LAN/VPN and
  do not forward port `443` from the internet. This endpoint is served directly
  by `cho-1`, not through Baleroc.
- The router needs a DHCP reservation for MAC `02:38:9a:9f:02:ab`. Point the
  LAN DNS record for `ollama.raboes28.nl` at that reserved address.
- If this workload was already deployed as `jarvis`, copy its Ollama data from
  `/mnt/ssd/jarvis/1/var/lib/ollama` and
  `/mnt/zdata/jarvis/1/var/lib/ollama/models` to the corresponding `cho`
  directories before starting `cho-1`. Stop `jarvis-1` first so both containers
  do not compete for its reserved address; keep the old data until the new
  container, models, and `ollama.raboes28.nl` certificate are confirmed working.

## Handy commands

Run on the host.

```bash
# Shell / logs
sudo nixos-container root-login cho-1
sudo nixos-container run cho-1 -- journalctl -u ollama.service -f
sudo nixos-container run cho-1 -- journalctl -u nginx.service -f

# Models
sudo nixos-container run cho-1 -- ollama list
sudo nixos-container run cho-1 -- ollama run mistral-small:latest

# Check the HTTPS endpoint and certificate
curl -sS https://ollama.raboes28.nl/api/tags
echo | openssl s_client -connect ollama.raboes28.nl:443 -servername ollama.raboes28.nl 2>/dev/null | openssl x509 -noout -dates -subject

# Container lifecycle (avoid unless recovering)
sudo nixos-container restart cho-1
```

## What runs here

- Ollama listens on localhost port `11434`, so it is not directly exposed to
  the LAN.
- Nginx terminates TLS using the certificate issued by [medivh](../medivh/README.md)
  and proxies requests to Ollama on port `11435`.
- `mistral-small:latest` is downloaded automatically. `syncModels = true` keeps
  the installation synchronized with the declared model list, so update
  [service-ollama.nix](service-ollama.nix) before adding other persistent models.

## Persistent data

- `/mnt/ssd/cho/1/var/lib/ollama` stores Ollama service state.
- `/mnt/zdata/cho/1/var/lib/ollama/models` stores downloaded models.
- `/mnt/ssd/medivh/1/var/lib/acme/ollama.raboes28.nl` provides the read-only TLS
  certificate.
