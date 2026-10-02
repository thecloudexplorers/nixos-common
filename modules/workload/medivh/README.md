# medivh

Central ACME / Let's Encrypt certificate authority client (container `medivh-1`).
It issues the certificates for all other workloads using DNS-01 through TransIP.

## Handy commands

Run on the host.

```bash
# Shell / logs
sudo nixos-container root-login medivh-1
sudo nixos-container run medivh-1 -- journalctl -u 'acme-*' -f
sudo nixos-container run medivh-1 -- journalctl -u acme-ironforge.raboes28.nl.service -n 100 --no-pager

# Overview of the certificate services and renewal timers
sudo nixos-container run medivh-1 -- systemctl list-units 'acme-*'
sudo nixos-container run medivh-1 -- systemctl list-timers 'acme-*'

# Force a renewal of one certificate (re-runs the postRun hook too)
sudo nixos-container run medivh-1 -- systemctl start acme-nextcloud.raboes28.nl.service
sudo nixos-container run medivh-1 -- systemctl start acme-idm.raboes28.nl.service
sudo nixos-container run medivh-1 -- systemctl start acme-ironforge.raboes28.nl.service

# Check expiry of the issued certificates
sudo openssl x509 -noout -subject -enddate -in /mnt/ssd/medivh/1/var/lib/acme/nextcloud.raboes28.nl/cert.pem
sudo openssl x509 -noout -subject -enddate -in /mnt/ssd/heartstone/var/lib/acme/idm.raboes28.nl/cert.pem
sudo openssl x509 -noout -subject -enddate -in /mnt/ssd/ironforge/1/var/lib/postgresql/secrets/cert.pem

# ACME credentials (read-only mounts from the host)
ls -la /mnt/ssd/medivh/environments /mnt/ssd/medivh/secrets

# Container lifecycle (avoid unless recovering)
sudo nixos-container restart medivh-1
```

The bind mounts that decide where each certificate lands are in
[container-1/container-1.nix](container-1/container-1.nix).

## What runs here

The ACME configuration lives in [acme/](acme/):

- [service-acme.nix](acme/service-acme.nix): shared defaults (production Let's
  Encrypt, DNS-01 via `transip`, `ec256` keys, daily renewal with 6h jitter,
  renew when fewer than 9 days remain).
- [service-acme-nextcloud.nix](acme/service-acme-nextcloud.nix): certificate for
  `nextcloud.raboes28.nl` (used by `dalaran` and `baleroc`).
- [service-acme-idm.nix](acme/service-acme-idm.nix): certificate for
  `idm.raboes28.nl` (used by `heartstone` and `baleroc`).
- [service-acme-ironforge.nix](acme/service-acme-ironforge.nix): certificate for
  `ironforge.raboes28.nl`. A `postRun` hook copies it into PostgreSQL's secrets
  directory with the owner and modes PostgreSQL requires.

## Dependencies

| Dependency                                      | Purpose                                                                      |
| ----------------------------------------------- | ---------------------------------------------------------------------------- |
| TransIP API credentials                         | DNS-01 challenge (`/mnt/ssd/medivh/environments`, `/mnt/ssd/medivh/secrets`) |
| `dalaran`, `heartstone`, `ironforge`, `baleroc` | Consumers of the certificates                                                |

## Persistent data (host bind mounts)

- `/mnt/ssd/medivh/1/var/lib/acme` holds the issued certificates and account.
- `/mnt/ssd/medivh/1/var/log/acme` holds the logs.
- `/mnt/ssd/medivh/{environments,secrets}` holds the TransIP credentials (read-only).
- The `heartstone` and `ironforge` certificate and secrets directories are
  writable mounts, so this workload can write certificates there.

## Notes

- To test changes without hitting Let's Encrypt rate limits, set
  `letsEncryptStaging = true` in [acme/service-acme.nix](acme/service-acme.nix)
  temporarily.
- Consumers read certificates from the shared `acme` group (gid 966). A
  consumer failing with permission errors usually means the group or mode is off.
- After a renewal, services that don't reload automatically (e.g. PostgreSQL)
  need a reload or restart to pick up the new certificate.
