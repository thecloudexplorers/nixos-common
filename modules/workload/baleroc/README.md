# baleroc

Public facing nginx reverse proxy (container `baleroc-1`).

## Handy commands

Run on the host.

```bash
# Shell / logs
sudo nixos-container root-login baleroc-1
sudo nixos-container run baleroc-1 -- journalctl -u nginx.service -f
sudo nixos-container run baleroc-1 -- tail -f /var/log/nginx/access.log /var/log/nginx/error.log

# nginx
sudo nixos-container run baleroc-1 -- systemctl status nginx
sudo nixos-container run baleroc-1 -- nginx -T          # dump the effective config
sudo nixos-container run baleroc-1 -- systemctl reload nginx

# Check certificates being served
echo | openssl s_client -connect nextcloud.raboes28.nl:443 -servername nextcloud.raboes28.nl 2>/dev/null | openssl x509 -noout -dates -subject
echo | openssl s_client -connect idm.raboes28.nl:443 -servername idm.raboes28.nl 2>/dev/null | openssl x509 -noout -dates -subject
echo | openssl s_client -connect brann.raboes28.nl:443 -servername brann.raboes28.nl 2>/dev/null | openssl x509 -noout -dates -subject

# Check backend reachability from the proxy
sudo nixos-container run baleroc-1 -- getent hosts nextcloud.raboes28.nl idm.raboes28.nl brann.raboes28.nl
sudo nixos-container run baleroc-1 -- curl -sI https://nextcloud.raboes28.nl
sudo nixos-container run baleroc-1 -- curl -sI https://idm.raboes28.nl
sudo nixos-container run baleroc-1 -- curl -sI https://brann.raboes28.nl

# Rate limiting (HTTP 429 on idm and brann)
sudo nixos-container run baleroc-1 -- grep ' 429 ' /var/log/nginx/access.log

# Container lifecycle (avoid unless recovering)
sudo nixos-container restart baleroc-1
```

## What runs here

[service-nginx.nix](service-nginx.nix) defines the vhosts:

- `nextcloud.raboes28.nl` proxies to `dalaran-1` (websockets on, 16G uploads,
  unbuffered streaming, long timeouts).
- `idm.raboes28.nl` proxies to `heartstone-1` (Kanidm), rate limited to 10 r/s
  per client IP (burst 30).
- `brann.raboes28.nl` proxies to `brann-1` (Open WebUI; websockets on, 100m
  uploads, unbuffered streaming, long timeouts), rate limited to 20 r/s per
  client IP (burst 100, since the web app loads many assets at once). Login is
  Kanidm only.
- A catch-all `_` vhost refuses TLS for unknown names and drops plain HTTP (444).

Backends are reached through static `networking.extraHosts` entries (the
DHCP-reserved LAN IPs of `dalaran-1`, `heartstone-1` and `brann-1`), not through public DNS.
The proxy verifies the backend certificate against the system CA bundle.

## Dependencies

| Dependency                         | Purpose                                                   |
| ---------------------------------- | --------------------------------------------------------- |
| `medivh`                           | Issues the Let's Encrypt certificates (mounted read-only) |
| `dalaran` / `heartstone` / `brann` | Backends                                                  |
| Router DHCP reservations           | Backend IPs in `service-nginx.nix` must match             |

## Persistent data

None. Certificates are read-only mounts from:

- `/mnt/ssd/medivh/1/var/lib/acme/nextcloud.raboes28.nl`
- `/mnt/ssd/heartstone/var/lib/acme/idm.raboes28.nl`
- `/mnt/ssd/medivh/1/var/lib/acme/brann.raboes28.nl`

## Notes

If a backend's LAN IP changes (DHCP reservation lost), update the IPs in
[service-nginx.nix](service-nginx.nix) and the container's `networking-1.nix`.
