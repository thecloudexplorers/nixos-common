# ironforge

PostgreSQL database server (container `ironforge-1`), reachable at
`ironforge.raboes28.nl:5432` over TLS.

## Handy commands

Run on the host.

```bash
# Shell / logs
sudo nixos-container root-login ironforge-1
sudo nixos-container run ironforge-1 -- journalctl -u postgresql.service -f
sudo nixos-container run ironforge-1 -- systemctl status postgresql
ls -la /mnt/ssd/ironforge/1/var/log/postgresql

# psql
sudo nixos-container run ironforge-1 -- sudo -u postgres psql -c '\l'          # databases
sudo nixos-container run ironforge-1 -- sudo -u postgres psql -c '\du'         # roles
sudo nixos-container run ironforge-1 -- sudo -u postgres psql -d nextcloud -c '\dt'

# Activity / health
sudo nixos-container run ironforge-1 -- sudo -u postgres psql -c 'SELECT pid, usename, datname, client_addr, state, now() - query_start AS running FROM pg_stat_activity ORDER BY running DESC NULLS LAST;'
sudo nixos-container run ironforge-1 -- sudo -u postgres psql -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database;"
sudo nixos-container run ironforge-1 -- sudo -u postgres psql -c 'SHOW ssl;'

# Backup / restore
sudo nixos-container run ironforge-1 -- sudo -u postgres pg_dump -Fc nextcloud > nextcloud-$(date +%F).dump
sudo nixos-container run ironforge-1 -- sudo -u postgres pg_restore -d nextcloud --clean --if-exists < nextcloud-<date>.dump

# TLS certificate in use (copied here by medivh)
sudo ls -la /mnt/ssd/ironforge/1/var/lib/postgresql/secrets
sudo openssl x509 -in /mnt/ssd/ironforge/1/var/lib/postgresql/secrets/cert.pem -noout -dates -subject
echo | openssl s_client -starttls postgres -connect ironforge.raboes28.nl:5432 2>/dev/null | openssl x509 -noout -dates

# Container lifecycle (avoid unless recovering)
sudo nixos-container restart ironforge-1
```

## What runs here

- **PostgreSQL** ([service-postgresql.nix](service-postgresql.nix)) with TCP
  enabled and SSL required to be available (`ssl = true`).
- Declaratively ensured database and role: `nextcloud`.
- `pg_hba` allows `nextcloud` from `dalaran-1`'s LAN IP (`192.168.1.69/32`)
  using `trust`. Access control is therefore by source IP and the firewall.

## Dependencies

| Dependency | Purpose                                                                                                         |
| ---------- | --------------------------------------------------------------------------------------------------------------- |
| `medivh`   | Issues the `ironforge.raboes28.nl` certificate and copies it into the postgres secrets directory (postRun hook) |
| `dalaran`  | The only client                                                                                                 |

## Persistent data (host bind mounts)

- `/mnt/ssd/ironforge/1/var/lib/postgresql` holds the data directory and the
  `secrets` subdirectory (`cert.pem`, `key.pem`, owned by postgres).
- `/mnt/ssd/ironforge/1/var/log/postgresql` holds the logs.

## Notes

- PostgreSQL requires `ssl_key_file` to be owned by `postgres` (or root), which
  is why the certificate is copied rather than read from the ACME mount.
- The postgres uid/gid (71) must stay the same across the host and the
  containers (see `modules/users/users/workloads/postgres.nix`).
- If the certificate was not copied yet, PostgreSQL fails to start. Trigger a
  renewal in `medivh` (see its README).
- The backups above are manual. Nothing schedules them yet.
