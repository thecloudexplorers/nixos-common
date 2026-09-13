# Random command collection for managing containers

## Login into the containers

on the HOST
```bash
sudo nixos-container root-login medivh-1
sudo nixos-container root-login heartstone-1
journalctl -b -p 5
```

# reboot  the containers

> NOTE: DO NOT DO THIS UNLESS YOU HAVE NO OTHER OPTION, THIS BREAKS THE CONTAINER MANAGEMENT FROM NIX!
> NOTE: There are 2 ways of fixing issue when containers are badly broken, reboot the server or comment out the containers run a build, switch and switch back to the containers again. This will recreate the all containers from from scratch
sudo systemctl stop container@heartstone-1
sudo systemctl start container@heartstone-1
sudo systemctl restart container@heartstone-1

sudo nixos-container restart medivh-1

## Remove all container folders

sudo rm -rf /var/lib/nixos-containers/heartstone-1
sudo rm -rf  /var/lib/nixos-containers/medivh-1

sudo rm -rf /mnt/ssd/medivh
sudo rm -rf /mnt/ssd/heartstone
sudo rm -rf /mnt/zdata/heartstone

## Set bindmount permissions

sudo bash scripts/set-bindmount-permissions.sh \
    modules/workload/medivh/container-1/container-1.nix \
    modules/workload/heartstone/container-1/container-1.nix

## Provision files for secrets / ACME workload

In order to bootstrap the ACME workload (`medivh`), provision an env file and a secret file for the DNS challenge.

1. Execute: `nano /mnt/ssd/medivh/environments/acme-transip-env`
2. Paste content like the following:

```bash
TRANSIP_ACCOUNT_NAME = ""
TRANSIP_PRIVATE_KEY_PATH = "/var/lib/acme/secrets/acme-transip-secret"
TRANSIP_POLLING_INTERVAL = "10"
TRANSIP_PROPAGATION_TIMEOUT = "600"
TRANSIP_TTL = "10"
```

1. Execute: `nano /mnt/ssd/medivh/secrets/acme-transip-secret`
2. Paste [content](https://www.transip.nl/cp/account/api/) like the following:

```bash
-----BEGIN PRIVATE KEY-----

-----END PRIVATE KEY-----
```

sudo nixos-rebuild switch --flake ~/dev/gh/devjevnl/nixos-config#faml-pc-home_server

## Ip Address check

find the container's current IP first

```bash
`sudo nixos-container run heartstone-1 -- ip -4 addr show eth0`

then test using that IP directly, without relying on DNS

`curl -vk --resolve idm.raboes28.nl:443:<that-ip> https://idm.raboes28.nl/status`
```
