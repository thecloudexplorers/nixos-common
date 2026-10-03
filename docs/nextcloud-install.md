# Nextcloud Installation Runbook

This document describes the end-to-end flow for your current setup:

- host machine: faml-pc-homeserver
- container name: dalaran-1
- Nextcloud service: nextcloud
- FQDN: nextcloud.raboes28.nl
- database: PostgreSQL runs in a separate container, `ironforge-1`
  (`ironforge.raboes28.nl:5432`), not locally inside `dalaran-1`
- apps: all Nextcloud apps are installed declaratively via `extraApps` in
  [service-nextcloud.nix](../modules/workload/dalaran/service-nextcloud.nix);
  the Nextcloud App Store is disabled (`appstoreEnable = false`) since apps
  are managed by Nix, not fetched at runtime

If you're new to this setup, read "How this works" and the "Glossary" at the
bottom first — the rest of this document assumes you know what a container,
`occ`, and a bind mount are.

## How this works (read this if you're new)

- Nextcloud does **not** run directly on the host. It runs inside a
  lightweight Linux container called `dalaran-1`, managed by
  `systemd-nspawn` (NixOS calls this a "nixos-container"). Think of it as a
  small isolated mini-VM with its own filesystem and services, sharing the
  host's kernel.
- The PostgreSQL database also runs in its **own separate container**,
  `ironforge-1`, reachable at `ironforge.raboes28.nl:5432`. Nextcloud (in
  `dalaran-1`) talks to it over the network like it would to any remote
  database server.
- All of Nextcloud's persistent data (uploaded files, config, database
  connection settings) lives on the **host**, not inside the container, via
  bind mounts (e.g. `/mnt/ssd/dalaran/1/var/lib/nextcloud` on the host is
  mounted as `/var/lib/nextcloud` inside the container). This means you can
  destroy and recreate the container without losing data, and conversely,
  wiping those host directories means a genuinely clean reinstall.
- The whole system is defined as code (Nix). To change anything permanently,
  you edit `.nix` files in this repo and run `nixos-rebuild switch`. Running
  commands directly inside the container (e.g. editing files by hand) is
  fine for debugging but will be **undone** on the next rebuild if it
  contradicts the Nix config.
- `occ` is Nextcloud's built-in command-line admin tool. NixOS runs it
  automatically via `nextcloud-setup.service` every time the container
  starts, to install the app (first run only) and enable configured apps.

## 1. Host preflight (one-time)

Run these from the host. They provision the bind-mounted admin password file
that nextcloud-setup reads during first bootstrap.

```bash
sudo nixos-rebuild switch --flake ~/dev/gh/devjevnl/nixos-config#faml-pc-home_server
sudo install -d -m 0700 /mnt/ssd/dalaran/1/secrets/admin
sudo sh -c 'printf "%s\n" "REPLACE_WITH_STRONG_ADMIN_PASSWORD" > /mnt/ssd/dalaran/1/secrets/admin/nextcloud-admin-pass'
sudo chmod 0600 /mnt/ssd/dalaran/1/secrets/admin/nextcloud-admin-pass
sudo chown root:root /mnt/ssd/dalaran/1/secrets/admin/nextcloud-admin-pass
sudo systemctl restart container@dalaran-1
```

## 2. Enter the container

From this point on, run commands inside the container shell.

```bash
sudo nixos-container root-login dalaran-1
journalctl -u nextcloud-setup.service
journalctl -u systemd-tmpfiles-setup


ls -ld /var/lib/nextcloud /var/lib/nextcloud/data /var/lib/nextcloud/data/config
```

## 3. Verify bootstrap secret inside container

```bash
ls -ld /tmp/dalaran-admin
ls -l /tmp/dalaran-admin
test -f /tmp/dalaran-admin/nextcloud-admin-pass && echo OK
```

Expected result:

- `/tmp/dalaran-admin` exists
- `nextcloud-admin-pass` exists
- command prints `OK`

## 4. Run setup service

```bash
systemctl restart nextcloud-setup.service
systemctl status nextcloud-setup.service --no-pager -l
journalctl -u nextcloud-setup.service -n 120 --no-pager
```

Expected result:

- `nextcloud-setup.service` is `active (exited)`
- no `status=243/CREDENTIALS` errors

## 5. Verify runtime services

```bash
systemctl is-active postgresql
systemctl is-active redis-nextcloud
systemctl is-active nginx
systemctl is-active nextcloud-cron
```

Expected result:

- all services report `active`

## 6. Verify network and app response

Inside the container:

```bash
ip addr show eth0
curl -vk https://nextcloud.raboes28.nl/status.php
```

Expected result:

- `status.php` returns HTTP 200 with JSON output

## 7. First login

- Open `https://nextcloud.raboes28.nl`
- Login with admin user `admin`
- Use the password in `/tmp/dalaran-admin/nextcloud-admin-pass`

## 8. Troubleshooting

### nextcloud-setup.service fails with CREDENTIALS

Symptom:

- `Failed to set up credentials: No such file or directory`
- `status=243/CREDENTIALS`

Inside container:

```bash
ls -la /tmp/dalaran-admin
systemctl cat nextcloud-setup.service
systemctl restart nextcloud-setup.service
journalctl -u nextcloud-setup.service -n 120 --no-pager
```

If `/tmp/dalaran-admin/nextcloud-admin-pass` is missing, exit the container,
recreate the host-side file under `/mnt/ssd/dalaran/1/secrets/admin`, restart
`container@dalaran-1`, and retry.

### setup keeps failing after password changes

The admin password file is only used during first-time bootstrap. If setup
already completed once, changing this file does not rotate the admin password.

### nextcloud-setup.service fails with "is not owned by user 'nextcloud'"

Symptom:

- `/var/lib/nextcloud/data/config is not owned by user 'nextcloud'!`

Cause: the host-side bind-mounted directories were created/recreated as
`root` (e.g. after a manual data wipe) instead of by `systemd-tmpfiles`.
Host-side tmpfiles rules cannot resolve the `nextcloud` username since it
only exists inside the container, so ownership must be fixed manually.

From the host:

```bash
sudo nixos-container run dalaran-1 -- id -u nextcloud
# note the UID (e.g. 998), then:
sudo chown -R <uid>:<uid> /mnt/ssd/dalaran/1/var/lib/nextcloud
sudo chown -R <uid>:<uid> /mnt/zdata/dalaran/1/var/lib/nextcloud/data
sudo nixos-container run dalaran-1 -- systemctl restart nextcloud-setup.service
```

### nextcloud-setup.service fails with "Cannot write into apps directory"

Symptom:

- The log shows `Nextcloud was successfully installed`, then repeated lines
  `Cannot write into "apps" directory. This can usually be fixed by giving
  the web server write access to the apps directory or disabling the App
  Store in the config file.` (one per app), ending in `status=1/FAILURE`.

Cause: this NixOS module always defines a writable `store-apps` app root for
the App Store, enabled by default unless `appstoreEnable` is explicitly set
to `false`. Since apps here are all pinned via `extraApps` (read-only
Nix-store symlinks), that writable directory is never created, so `occ
app:enable` fails its writability check and the whole oneshot service exits
non-zero — even though the database install itself already succeeded.

Fix: set `services.nextcloud.appstoreEnable = false;` in
[service-nextcloud.nix](../modules/workload/dalaran/service-nextcloud.nix)
(already applied), then rebuild and rerun setup.

### Benign "Error trying to connect as postgres" warning

During first install you may see a stack trace logged as
`Error trying to connect as "postgres", assuming database is setup and
tables need to be created`, sometimes including a `no pg_hba.conf entry`
error. This is Nextcloud's own defensive fallback probe during
`maintenance:install` and is expected/harmless as long as it's followed by
`Nextcloud was successfully installed` — it is not the cause of setup
failures.

### Container fails to start: "File exists" (stale network interface)

Symptom (from `journalctl -u container@dalaran-1` or `systemctl status
container@dalaran-1`):

- `Failed to add new veth interfaces (vb-dalaran-1:host0): File exists`

Cause: a previous crashed/killed container start left a leftover virtual
network interface on the host's bridge. It's harmless clutter, not a real
network conflict, but it blocks the new container from creating its own.

Fix, from the host:

```bash
ip link show vb-dalaran-1        # confirm it exists
sudo ip link delete vb-dalaran-1
sudo systemctl reset-failed container@dalaran-1
sudo systemctl restart container@dalaran-1
```

(Replace `dalaran-1` with `ironforge-1` or any other container name if that
one is affected instead.)

### Container fails to start: "Machine already exists"

Symptom:

- `Failed to register machine: Machine 'dalaran-1' already exists`

Cause: `systemd-machined` still has a stale registration from a previous
crashed start, even though the container process itself is gone.

Fix, from the host:

```bash
machinectl list                       # see what's registered
sudo machinectl terminate dalaran-1   # or: sudo machinectl poweroff dalaran-1
sudo systemctl restart container@dalaran-1
```

If this keeps recurring together with the stale-veth issue above and
cleaning up one keeps surfacing the other, the fastest reliable fix is to
**reboot the whole host machine** — this clears all leftover networking and
machined state at once:

```bash
sudo reboot
```

### ironforge-1 (PostgreSQL) fails: "could not access private key file"

Symptom (from `journalctl -u postgresql` inside `ironforge-1`):

- `could not access private key file "/var/lib/postgresql/secrets/key.pem":
  No such file or directory`

Cause: PostgreSQL's TLS cert/key are copied into place by an ACME `postRun`
hook, but that hook only runs when a certificate is actually **renewed**. If
the certificate for `ironforge.raboes28.nl` already existed before this hook
was added, the key/cert were never copied and need a one-time manual
bootstrap.

Fix, inside the `medivh-1` container (which holds the issued certs):

```bash
sudo nixos-container root-login medivh-1
cp -fpL /var/lib/acme/ironforge.raboes28.nl/cert.pem  /var/lib/private/postgresql/cert.pem
cp -fpL /var/lib/acme/ironforge.raboes28.nl/key.pem   /var/lib/private/postgresql/key.pem
chown postgres:postgres /var/lib/private/postgresql/cert.pem /var/lib/private/postgresql/key.pem
chmod 644 /var/lib/private/postgresql/cert.pem
chmod 600 /var/lib/private/postgresql/key.pem
ls -la /var/lib/private/postgresql/
exit
```

Then, from the host:

```bash
sudo nixos-container run ironforge-1 -- systemctl reset-failed postgresql
sudo nixos-container run ironforge-1 -- systemctl restart postgresql
sudo nixos-container run ironforge-1 -- journalctl -u postgresql -n 40 --no-pager
```

Expected: `database system is ready to accept connections`.

### PostgreSQL check

```bash
journalctl -u postgresql -n 120 --no-pager
```

### Nginx / TLS check

```bash
journalctl -u nginx -n 120 --no-pager
```

## 9. Clean reinstall (start completely from scratch)

Use this only if Nextcloud's config/database has gotten into a broken state
you can't recover from (e.g. `config.php` pointing at an old database) and
you want to wipe everything and reinstall fresh. **This permanently deletes
all Nextcloud data** (files, users, settings) — there is no undo.

1. Comment out the container's import in
   [configuration.nix](../modules/computer/server/faml-pc-home_server/configuration.nix)
   (the line importing `../../../workload/dalaran/container-1/container-1.nix`).
2. Rebuild to tear the container down:
   ```bash
   sudo nixos-rebuild switch --flake ~/dev/gh/devjevnl/nixos-config#faml-pc-home_server
   ```
3. Delete the persistent host-side data (irreversible — double-check the
   paths before running):
   ```bash
   sudo rm -rf /mnt/ssd/dalaran/1/var/lib/nextcloud
   sudo rm -rf /mnt/zdata/dalaran/1/var/lib/nextcloud/data
   ```
4. Uncomment the container import from step 1.
5. Rebuild again to recreate the container and directories:
   ```bash
   sudo nixos-rebuild switch --flake ~/dev/gh/devjevnl/nixos-config#faml-pc-home_server
   ```
6. If the container fails to start, check for stale networking/machined
   state (see the two troubleshooting entries above).
7. Once the container is running, the directories were likely created as
   `root` instead of `nextcloud` — fix ownership as described in
   "nextcloud-setup.service fails with 'is not owned by user nextcloud'"
   above.
8. Restart setup and confirm success:
   ```bash
   sudo nixos-container run dalaran-1 -- systemctl restart nextcloud-setup.service
   sudo nixos-container run dalaran-1 -- journalctl -u nextcloud-setup -n 100 --no-pager
   ```
   Look for `Nextcloud was successfully installed` and the service ending in
   `Finished nextcloud-setup.service` (not `FAILURE`).

## Glossary

- **nixos-container**: NixOS's built-in tool for running lightweight Linux
  containers (via `systemd-nspawn`). Each one behaves like a small separate
  machine with its own filesystem, services, and (optionally) network
  address.
- **bind mount**: a way of making a host directory appear at a path inside a
  container, so both the host and the container see the exact same files.
  Used here so Nextcloud's data survives container recreation.
- **occ**: Nextcloud's command-line admin tool, used for installation,
  upgrades, and app management. Runs automatically via
  `nextcloud-setup.service`; can also be run manually inside the container.
- **journalctl**: the command to read systemd service logs, e.g.
  `journalctl -u <service-name> -n 100 --no-pager` shows the last 100 lines
  for that service without a pager.
- **veth / bridge (`br0`)**: virtual network cable pairs and a virtual
  switch NixOS uses to give containers network access. Stale leftovers from
  crashed container starts are a common source of "already exists" errors.
- **ACME**: the protocol used to automatically request/renew TLS
  certificates (e.g. from Let's Encrypt). `security.acme` handles this in
  NixOS.
- **tmpfiles rules** (`systemd.tmpfiles.rules`): declarative rules that
  create/set ownership on directories at boot. They can't resolve usernames
  that only exist inside a container, which is why some directories need
  manual `chown` after a reset.
