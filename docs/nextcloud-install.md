# Nextcloud Installation Runbook

This document describes the end-to-end flow for your current setup:

- host machine: faml-pc-homeserver
- container name: dalaran-1
- Nextcloud service: nextcloud
- FQDN: nextcloud.raboes28.nl

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

### PostgreSQL check

```bash
journalctl -u postgresql -n 120 --no-pager
```

### Nginx / TLS check

```bash
journalctl -u nginx -n 120 --no-pager
```
