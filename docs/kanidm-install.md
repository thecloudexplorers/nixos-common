# Kanidm Installation Runbook

This document describes the end-to-end flow for your current setup:

- host machine: faml-pc-homeserver
- container name: heartstone-1
- Kanidm service: kanidm

## 1. Enter the container

```bash
sudo nixos-container root-login heartstone-1
```

## 2. Preflight checks (inside container)

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

## 3. Recover bootstrap admin accounts (inside container)

Use the server CLI (`kanidmd`) to recover both built-in accounts:

```bash
kanidmd recover-account admin
kanidmd recover-account idm_admin
```

Save both generated passwords.

## 4. Login with client CLI (host)

Exit the container and login from the host using the client tool (`kanidm`):

```bash
kanidm login --name idm_admin
```

If you need to override URL explicitly:

```bash
kanidm login --name idm_admin --url https://idm.raboes28.nl
```

## 5. Create your first user (host)

```bash
kanidm person create <your-username> "Your Display Name"

EXAMPLE: kanidm person create jdoe "John Doe"
```

Verify user exists:

```bash
kanidm person list
```

## 6. Set first password for the new user (host)

Create a reset token as admin:

```bash
kanidm person credential create-reset-token <your-username>

EXAMPLE: kanidm person credential create-reset-token jdoe
```

Use the token to set credentials:

```bash
kanidm person credential use-reset-token
```

If prompted for MFA requirements, complete TOTP enrollment in the flow.

## 7. Optional account checks (host)

```bash
kanidm person credential status <your-username>
kanidm group list
```

## 8. Troubleshooting

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
