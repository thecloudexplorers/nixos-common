# Kanidm Installation Runbook

This document describes the end-to-end flow for your current setup:

- host machine: faml-pc-homeserver
- container name: heartstone-1
- Kanidm service: kanidm
- FQDN: idm.raboes28.nl

If you're new to this setup, read "How this works" and the "Glossary" at the
bottom first.

## How this works (read this if you're new)

- Kanidm (the identity/SSO server) runs inside its own lightweight Linux
  container, `heartstone-1`, managed by `systemd-nspawn` (NixOS calls this a
  "nixos-container"). It behaves like a small separate machine sharing the
  host's kernel.
- Persistent data (the Kanidm database, TLS secrets, backups) lives on the
  **host** via bind mounts (e.g. `/mnt/ssd/heartstone/1/var/lib/kanidm` on
  the host is mounted as `/var/lib/kanidm` inside the container), so it
  survives container recreation.
- There are **two different command-line tools**, easy to confuse:
  - `kanidmd` — the **server** admin tool. Only exists inside the
    `heartstone-1` container. Used for local/offline operations like
    recovering admin passwords or reindexing the database.
  - `kanidm` — the **client** tool. Runs on the host (or anywhere with
    network access) and talks to the server over HTTPS, like a regular user
    or admin would.
- Some users/groups (`marlous`, `peon`, `faml-users`, `test-users`) are
  already declared **declaratively** in
  [service-kanidm.nix](../modules/workload/heartstone/service-kanidm.nix)
  under `services.kanidm.provision`. Prefer adding users there and
  redeploying over the manual `kanidm person create` steps below — manual
  steps are best reserved for one-off/test accounts not meant to live in Nix.
- TLS certificates are issued by a separate ACME/cert-issuing workload and
  mounted **read-only** into the container. Unlike some other workloads in
  this repo, there's no automated hook that copies the certificate into the
  path Kanidm actually reads from (`/var/lib/kanidm/secrets/`) — that copy
  is a manual one-time step, covered in section 1 below.

## 1. Host preflight: certificate bootstrap (one-time)

Kanidm reads its TLS certificate and key from
`/var/lib/kanidm/secrets/fullchain.pem` and `.../key.pem` inside the
container, but the issued certificate is only mounted read-only at
`/var/lib/acme/idm.raboes28.nl/`. These need to be copied into place once
(and again any time the certificate is renewed, since there's no automatic
copy hook for this workload).

From the host:

```bash
sudo nixos-rebuild switch --flake ~/dev/gh/devjevnl/nixos-config#faml-pc-home_server
sudo nixos-container root-login heartstone-1
```

Inside the container:

```bash
cp -fpL /var/lib/acme/idm.raboes28.nl/fullchain.pem /var/lib/kanidm/secrets/fullchain.pem
cp -fpL /var/lib/acme/idm.raboes28.nl/key.pem       /var/lib/kanidm/secrets/key.pem
chown kanidm:kanidm /var/lib/kanidm/secrets/fullchain.pem /var/lib/kanidm/secrets/key.pem
chmod 600 /var/lib/kanidm/secrets/fullchain.pem /var/lib/kanidm/secrets/key.pem
ls -la /var/lib/kanidm/secrets/
systemctl restart kanidm
exit
```

Expected result:

- both files exist, owned by `kanidm`, mode `600`
- no more "permissions ... may not be secure" warnings in the logs (see
  section 3)

## 2. Enter the container

```bash
sudo nixos-container root-login heartstone-1
```

## 3. Preflight checks (inside container)

```bash
systemctl is-active kanidm
systemctl status kanidm --no-pager -l
journalctl -u kanidm -n 120 --no-pager
```

Expected result:

- `is-active` returns `active`
- status output shows `Active: active (running)`

Example trimmed and redacted log output:

```text
Sep 13 20:18:36 lxc-heartstone-1 kanidmd[295]: INFO  [info]: Starting Kanidmd | version: 1.11.1
Sep 13 20:18:36 lxc-heartstone-1 kanidmd[295]: INFO  [info]: Running in server mode
Sep 13 20:18:36 lxc-heartstone-1 kanidmd[295]: WARN  [warn]: permissions on /var/lib/kanidm/secrets/fullchain.pem may not be secure
Sep 13 20:18:36 lxc-heartstone-1 kanidmd[295]: WARN  [warn]: permissions on /var/lib/kanidm/secrets/key.pem may not be secure
Sep 13 20:18:36 lxc-heartstone-1 kanidmd[295]: INFO  [info]: Starting kanidm with configuration: address: [::]:443, domain: idm.example.tld, ldap address: [::]:636, origin: https://idm.example.tld
Sep 13 20:18:36 lxc-heartstone-1 kanidmd[295]: INFO  [info]: Migration path does not exist - migrations will be skipped | migration_path: /etc/kanidm/migrations.d
Sep 13 20:18:36 lxc-heartstone-1 kanidmd[295]: INFO  [info]: Online backup next run on 2026-09-13 22:00:00 UTC
Sep 13 20:18:36 lxc-heartstone-1 kanidmd[295]: INFO  [info]: Starting LDAPS interface ldaps://[::]:636
Sep 13 20:18:36 lxc-heartstone-1 kanidmd[295]: INFO  [info]: Starting the web server
Sep 13 20:18:36 lxc-heartstone-1 kanidmd[295]: INFO  [info]: Ready to rock! UI available at: https://idm.example.tld
Sep 13 20:18:36 lxc-heartstone-1 systemd[1]: Started kanidm identity management daemon.
```

If Kanidm is not running, exit the container and deploy from host:

```bash
exit
sudo nixos-rebuild switch --flake ~/dev/gh/devjevnl/nixos-config#faml-pc-home_server
sudo nixos-container root-login heartstone-1
```

## 4. Recover bootstrap admin accounts (inside container)

Use the server CLI (`kanidmd`) to recover both built-in accounts:

```bash
kanidmd recover-account admin
kanidmd recover-account idm_admin
```

Save both generated passwords.

Note: unlike Nextcloud's admin password file, `kanidmd recover-account` can
be run again at any time (the service does need to be stopped first, see
`kanidmd --help`) to reset that account's password — it isn't a one-time-only
bootstrap step.

## 5. Login with client CLI (host)

Exit the container and login from the host using the client tool (`kanidm`):

```bash
kanidm login --name idm_admin
```

If you need to override URL explicitly:

```bash
kanidm login --name idm_admin --url https://idm.raboes28.nl
```

## 6. Create your first user (host)

Prefer adding the user declaratively instead (see "How this works" above):
add an entry under `services.kanidm.provision.persons` in
[service-kanidm.nix](../modules/workload/heartstone/service-kanidm.nix), then
run `sudo nixos-rebuild switch --flake ~/dev/gh/devjevnl/nixos-config#faml-pc-home_server`.

For a one-off/test user not meant to live in Nix, create it manually instead:

```bash
kanidm person create <your-username> "Your Display Name"

EXAMPLE: kanidm person create jdoe "John Doe"
```

Verify user exists:

```bash
kanidm person list
```

## 7. Set first password for the new user (host)

Create a reset token as admin:

```bash
kanidm person credential create-reset-token <your-username>

EXAMPLE: kanidm person credential create-reset-token peon
```

Use the token to set credentials:

```bash
kanidm person credential use-reset-token
```

If prompted for MFA requirements, complete TOTP enrollment in the flow.

## 8. Optional account checks (host)

```bash
kanidm person credential status <your-username>
kanidm group list
```

## 9. Troubleshooting

### Container fails to start: "File exists" (stale network interface)

Symptom (from `journalctl -u container@heartstone-1` or `systemctl status
container@heartstone-1`):

- `Failed to add new veth interfaces (vb-heartstone-1:host0): File exists`

Cause: a previous crashed/killed container start left a leftover virtual
network interface on the host's bridge.

Fix, from the host:

```bash
ip link show vb-heartstone-1
sudo ip link delete vb-heartstone-1
sudo systemctl reset-failed container@heartstone-1
sudo systemctl restart container@heartstone-1
```

### Container fails to start: "Machine already exists"

Symptom:

- `Failed to register machine: Machine 'heartstone-1' already exists`

Fix, from the host:

```bash
machinectl list
sudo machinectl terminate heartstone-1   # or: sudo machinectl poweroff heartstone-1
sudo systemctl restart container@heartstone-1
```

If this keeps recurring together with the stale-veth issue above, reboot the
host to clear all leftover networking/machined state at once: `sudo reboot`.

### IP address check

Use this when DNS is not resolving as expected and you want to test the service
directly by container IP.

Find the container IP from inside the container:

```bash
ip addr show eth0
```

Look for the IPv4 address on `eth0` (for example `192.168.1.50`). Then run
this from the host, replacing `<that-ip>`:

```bash
curl -vk --resolve idm.raboes28.nl:443:<that-ip> https://idm.raboes28.nl/status
```

### Kanidmd not found inside container

Because the workload now includes the package, this should work:

```bash
kanidmd --help
```

If not, run a deploy again:

```bash
sudo nixos-rebuild switch --flake ~/dev/gh/devjevnl/nixos-config#faml-pc-home_server
```

### UI login works but /ui/apps returns 500

Reindex database from host:

```bash
sudo nixos-container run heartstone-1 -- systemctl stop kanidm
sudo nixos-container run heartstone-1 -- kanidmd db reindex -c /etc/kanidm/server.toml
sudo nixos-container run heartstone-1 -- systemctl start kanidm
sudo nixos-container run heartstone-1 -- journalctl -u kanidm -n 120 --no-pager
```

### DB permissions warning

Check ownership and write access inside container:

```bash
id kanidm
ls -ld /var/lib/kanidm
su -s /bin/sh -c 'test -w /var/lib/kanidm && echo writable || echo not-writable' kanidm
```

### "permissions on .../secrets/fullchain.pem may not be secure"

See section 1 ("Host preflight: certificate bootstrap") — the certificate
files either haven't been copied into `/var/lib/kanidm/secrets/` yet, or have
the wrong owner/mode. Re-run the copy/chown/chmod steps there.

## Glossary

- **nixos-container**: NixOS's built-in tool for running lightweight Linux
  containers (via `systemd-nspawn`). Each behaves like a small separate
  machine with its own filesystem, services, and network address.
- **bind mount**: a way of making a host directory appear at a path inside a
  container, so both host and container see the exact same files. Used here
  so Kanidm's database and secrets survive container recreation.
- **kanidmd vs kanidm**: `kanidmd` is the server daemon and its offline admin
  CLI (container-only); `kanidm` is the network client CLI (used from the
  host to talk to the running server).
- **provision**: a NixOS Kanidm module option for declaring users/groups in
  Nix instead of creating them by hand via the CLI.
- **journalctl**: the command to read systemd service logs, e.g.
  `journalctl -u kanidm -n 120 --no-pager` shows the last 120 lines.
- **veth / bridge (`br0`)**: virtual network cable pairs and a virtual
  switch NixOS uses to give containers network access. Stale leftovers from
  crashed container starts are a common source of "already exists" errors.
- **ACME**: the protocol used to automatically request/renew TLS
  certificates (e.g. from Let's Encrypt).
