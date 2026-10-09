# dalaran

Nextcloud (container `dalaran-1`), served over HTTPS by a local nginx.

## Handy commands

Run on the host. `nextcloud-occ` is Nextcloud's admin CLI.

```bash
# Shell / logs
sudo nixos-container root-login dalaran-1
sudo nixos-container run dalaran-1 -- journalctl -u nextcloud-cron.service -f
sudo nixos-container run dalaran-1 -- journalctl -u phpfpm-nextcloud.service -f
sudo nixos-container run dalaran-1 -- tail -f /var/lib/nextcloud/data/nextcloud.log

# Status / health
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ status
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ check
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ app:list
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ config:list system

# Background jobs
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ background-job:running
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ background-job:history
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ background-job:list
sudo nixos-container run dalaran-1 -- systemctl list-timers 'nextcloud-*'

# Preview generation (long running: use tmux/screen or systemd-run)
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ preview:pre-generate -vvv
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ preview:generate-all -vvv
sudo nixos-container run dalaran-1 -- systemd-run --uid=nextcloud --unit=preview-pregenerate nextcloud-occ preview:pre-generate -vvv
sudo nixos-container run dalaran-1 -- journalctl -u preview-pregenerate -f

# Files
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ files:scan --all
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ files:scan <user>

# Users / SSO (see docs/nextcloud-kanidm-sso.md)
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ user:list
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ user_oidc:provider kanidm

# Maintenance mode / repair
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ maintenance:mode --on
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ maintenance:mode --off
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ maintenance:repair
sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ db:add-missing-indices

# Container lifecycle (avoid unless recovering; see docs/go-horse-container-commands.md)
sudo nixos-container restart dalaran-1
```

## What runs here

- **Nextcloud 34** ([service-nextcloud.nix](service-nextcloud.nix)),
  with `configureRedis` for caching and `notify_push` for client push.
- **nginx** terminating TLS with the certificate issued by `medivh`.
- **Declarative apps** (`extraApps`): calendar, contacts, deck, notes, tasks,
  news, maps, spreed (Talk), richdocuments, user_oidc, previewgenerator, and
  others. The app store is disabled, so apps change only via the Nix config.
- **`nextcloud-oidc-setup`** oneshot service that (re)registers the Kanidm OIDC
  provider on every boot.
- **`nextcloud-ollama-setup`** oneshot service that (re)points the
  `integration_openai` app at the Ollama server in `cho`
  (`https://ollama.raboes28.nl/v1`, default model `qwen3.5:9b-q8_0`) on
  every boot, so the **Assistant** app (pinned to 3.5.0, the last release
  supporting Nextcloud 34) can use it. No API key is needed. `max_tokens` is
  raised to 8192 because qwen3.5 is a thinking model: with the default of 1000
  its reasoning can use the whole budget and the Assistant shows a blank reply.
- **`nextcloud-taskprocessing-worker`** long-running `occ taskprocessing:worker`
  that runs AI tasks immediately. Without it, tasks wait for the 5 minute cron
  run and the Assistant appears to hang.
- **ffmpeg** on the cron `PATH` for video previews.

## Dependencies

| Dependency       | Where                                      | Purpose            |
| ---------------- | ------------------------------------------ | ------------------ |
| PostgreSQL       | `ironforge` (`ironforge.raboes28.nl:5432`) | Database           |
| Kanidm           | `heartstone` (`idm.raboes28.nl`)           | SSO login          |
| ACME certificate | `medivh` (read-only mount)                 | TLS                |
| Reverse proxy    | `baleroc`                                  | Public entry point |
| Ollama           | `cho` (`ollama.raboes28.nl`)               | Assistant AI       |

## Persistent data (host bind mounts)

- `/mnt/ssd/dalaran/1/var/lib/nextcloud` is the Nextcloud home.
- `/mnt/zdata/dalaran/1/var/lib/nextcloud/data` holds user data.
- `/mnt/ssd/dalaran/1/secrets/{admin,oidc}` holds the admin password and the
  OIDC client secret.

## Notes

- The background-job `Server ID` should be `1` (`serverid` in the config).
  Rows with other IDs are stale leftovers from dead processes.
- A `mkdir(): File exists` warning from the News app in the log is a harmless
  upstream race condition.
