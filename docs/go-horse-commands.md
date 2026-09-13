# Go Horse Commands

All 'Go Horse' quality commands to help bush-fix an otherwise perfect NixOS config.

## Nix Flake Commandos

Shows the configuration set-up
`nix flake show`

Chekcs the consistency and updates the falke.lock
`nix flake check`

Rebuilds the running NixOS using the specified flake
`nixos-rebuild build --flake ~/dev/gh/devjevnl/nixos-config#faml-pc-home_server`

Rebuilds the running NixOS using the specified flake
`sudo nixos-rebuild dry-activate --flake ~/dev/gh/devjevnl/nixos-config#faml-pc-home_server`

Rebuilds the running NixOS using the specified flake
`sudo nixos-rebuild boot --flake ~/dev/gh/devjevnl/nixos-config#faml-pc-home_server`

Rebuilds the running NixOS using the specified flake
`sudo nixos-rebuild switch --flake ~/dev/gh/devjevnl/nixos-config#faml-pc-home_server`

## Rebuild based on configuration.nix updates with switch

Don't forget to `sudo` for a switch as it adjusts your boot config (among others), which requires sudo. Only Home-Manager deployments without system level config can switch without `sudo`.

Just build, no changes to the live config or `boot` generations:
`nixos-rebuild build`

Build, compile, provision to `/nix/store/...`, but *do not* activate. So, no changes made to your live config/boot:
`nixos-rebuild dry-activate`

Build, compile, provision, and *add a new config after reboot* (no changes before reboot):
`nixos-rebuild boot`

Build, compile, provision, and *switch* the current (no reboot required) NixOS config:
`nixos-rebuild switch`

## Workaround for flake is experimental feature

Run: `sudo NIX_CONFIG="experimental-features = nix-command flakes" nixos-install --no-root-passwd`
      - Running `--no-root-passwd` to avoid keyboard issues during the installation process by failing to type the same the password twice.
      - `nixos-install` does not accept a `--extra-experimental-features` flag directly (its own argument parser rejects it with `unknown option`), so the feature must be enabled via the `NIX_CONFIG` environment variable instead, because the live installer's Nix does not have flakes enabled by default, even though `configuration.nix` enables it for the installed system.

## Building the NixImage

``` shell
cd /home/jev/dev/gh/devjevnl/nixos-config/
nix build .#usbInstallerFull
```

## Generate SSH Key for github

Keep in mind that this generates the SSH key locally in your `/home/<user>/.ssh` folder, which also provisions the `.pub` file. Just don't append the `-f` parameter with .pub, that is done automatically.

`ssh-keygen -t ed25519 -C "32514140+devjevnl@users.noreply.github.com" -f ~/.ssh/github-authentication`

## Get public Key to paste in github

Retrieve the pub key, ready for copy & paste where needed. *Include the empty line* when pasting in GitHub for auth/signing.

`cat ~/.ssh/github-authentication.pub`

## Clone GitHub Repo using ssh

Override the default SSH key for auth (for instance `~/.ssh/id_ed25519`), since you want GitHub specific auth/signing keys. Save the default generated key for HomeLab stuff.

`git clone git@github.com:devjevnl/nixos-config.git --config core.sshCommand="ssh -i ~/.ssh/github-authentication"`

## Provision files for secrets / ACME workload

In order to bootstrap the ACME workload (`medivh`), provision an env file and a secret file for the DNS challenge.

1. Execute: `nano /mnt/ssd/medivh/environments/acme-transip-env`
2. Paste content like the following:
``` plaintext
TRANSIP_ACCOUNT_NAME = "REPLACEMEWITHACCOUNTNAME"
TRANSIP_PRIVATE_KEY_PATH = "/var/lib/acme/secrets/acme-transip-secret"
TRANSIP_POLLING_INTERVAL = "10"
TRANSIP_PROPAGATION_TIMEOUT = "600"
TRANSIP_TTL = "10"
```
3. Execute: `nano /mnt/ssd/medivh/secrets/acme-transip-secret`
4. Paste [content](https://www.transip.nl/cp/account/api/) like the following:
``` plaintext
-----BEGIN PRIVATE KEY-----
REALLY SECRET ENCRYPTED STUFF HERE PASTED FROM TRANSIP TOKEN
-----END PRIVATE KEY-----
```
