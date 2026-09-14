# Random Commands For Managing Containers

All commands in this document are meant to run on the host unless noted
otherwise.

## Container locations

NixOS container runtime state is stored under:

`/var/lib/nixos-containers/`

Example paths for `heartstone-1`:

`/var/lib/nixos-containers/heartstone-1/`
`/var/lib/nixos-containers/heartstone-1/rootfs`

Persistent application data in this repo is stored via bind mounts under
`/mnt`, not in `/var/lib/nixos-containers`. Check the `hostPath` values in:

- `modules/workload/medivh/container-1/container-1.nix`
- `modules/workload/heartstone/container-1/container-1.nix`

## Login and quick logs

```bash
sudo nixos-container root-login medivh-1
sudo nixos-container root-login heartstone-1
journalctl -b -p 5
```

## Restart containers manually

WARNING: avoid manual restarts unless needed for recovery. Container lifecycle
is intended to be managed declaratively by NixOS.

```bash
sudo systemctl stop container@heartstone-1
sudo systemctl start container@heartstone-1
sudo systemctl restart container@heartstone-1

sudo nixos-container restart medivh-1
```

## Remove container folders

```bash
sudo rm -rf /var/lib/nixos-containers/heartstone-1
sudo rm -rf /var/lib/nixos-containers/medivh-1

sudo rm -rf /mnt/ssd/medivh
sudo rm -rf /mnt/ssd/heartstone
sudo rm -rf /mnt/zdata/heartstone
```

## Bind mount directories

The bind-mount host paths are now created and owned declaratively via NixOS
`systemd.tmpfiles` rules in the server configuration, which is the normal
operation path. The legacy shell script at
`scripts/set-bindmount-permissions.sh` remains available as a backup option if
manual recovery or troubleshooting is needed:

```bash
sudo bash /home/jev/dev/gh/devjevnl/nixos-config/scripts/set-bindmount-permissions.sh
```

## Provision files for ACME workload

To bootstrap ACME workload `medivh`, provide the DNS challenge env file and
secret file.

1. Edit `/mnt/ssd/medivh/environments/acme-transip-env`.
2. Add:

```bash
nano /mnt/ssd/medivh/environments/acme-transip-env
```

```bash
TRANSIP_ACCOUNT_NAME = ""
TRANSIP_PRIVATE_KEY_PATH = "/var/lib/acme/secrets/acme-transip-secret"
TRANSIP_POLLING_INTERVAL = "10"
TRANSIP_PROPAGATION_TIMEOUT = "600"
TRANSIP_TTL = "10"
```

1. Edit `/mnt/ssd/medivh/secrets/acme-transip-secret`.
1. Add your TransIP private key from
     [transip.nl/cp/account/api](https://www.transip.nl/cp/account/api/).

```bash
nano /mnt/ssd/medivh/secrets/acme-transip-secret
```

```bash
-----BEGIN PRIVATE KEY-----

-----END PRIVATE KEY-----
```

1. Rebuild and switch:

```bash
sudo nixos-rebuild switch --flake ~/dev/gh/devjevnl/nixos-config#faml-pc-home_server
```

## IP address check

Find the container IP first (inside the container):

```bash
ip addr show eth0
```

Then test the service directly by IP from the host (replace `<that-ip>`):

```bash
curl -vk --resolve idm.raboes28.nl:443:<that-ip> https://idm.raboes28.nl/status
```
