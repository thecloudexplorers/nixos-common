# NixOS Installation with Disko

## Commandline Install

To install NixOS from command-line, with disko, execute the following commands:

1. To create the desired partitions:
    - `sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount /run/media/nixos/Ventoy/disko-config.nix`
    - Validate the partitions were created and mounted correctly by running `lsblk`. This should result in the exact partitions found in your `disko-config.nix`.
2. If you need to validate hardware settings with a scan, run the following:
    - `sudo nixos-generate-config --no-filesystems --root /mnt`
3. Run the following commands:
    - `sudo cp /run/media/nixos/Ventoy/disko-config.nix /mnt/etc/nixos`.
    - `sudo cp /run/media/nixos/Ventoy/configuration.nix /mnt/etc/nixos/configuration.nix`.
4. To actually install NixOS on the newly created partitions:
    - `sudo nixos-install --no-root-passwd`
      - Running `--no-root-passwd` to avoid keyboard issues during the installation process by failing to type the same the password twice.
5. To set the root password manually execute:
    - `sudo nixos-enter --root '/mnt'`
    And then run the following in the shell of the new system:
    - `passwd`
    After succesfully setting the new password exit the chroot shell:
    - `logout`
6. If all has gone well:
    - `reboot`
7. After reboot, type the passphrase for the ssd and zfs pool.
    > NOTE: Keyboard delay for non wired keyboards before you can start typing the passphrase is about 10 seconds, so be patient!
8. You will run into the following error: [FAILED] Failed to start Import ZFS pool "zhdd"
9. Simply import the zfs pool manually the first tyme, by running the following command:
    - `zpool import -f zhdd`
   If issues persist, look in the ZFS Troubleshooting section below for more information.

Replace the `.../git/hosts/<Hostname>/disk-config.nix` and `.../git#<Hostname>` options with the intended configuration elements as relevant.

Further reading specific to Disko: [https://github.com/nix-community/disko/blob/master/docs/quickstart.md](https://github.com/nix-community/disko/blob/master/docs/quickstart.md)

### ZFS Troubleshooting

If the new install goes into emergency mode because the ZFS pool wouldn't load, do the following:

- `systemctl status zfs-import-zhdd.service`
- `zpool import -f zhdd`
- `systemctl restart zfs-import-zhdd.service`
- `reboot now`

### Post Install checks

>NOTE: The zhdd disks are not directly accessible from the GUI on the left hand side, only via the `/mnt` folder.

#### Adding a test file to the ZFS pool
In the dolphin file manager, open the home and navigate to  /mnt nand press enter.
You should see two folders `sdd` and `zdata`, open the `zdata` folder.
Rightclick in the empty space and see if `+ Create New` is available, it should be greyed out as current user does not have permissions to write on the ZFS pool.

Open console and run the following command to createa test file on the ZFS pool, which should succeed without errors:

`sudo nano /mnt/zdata/testfile.txt`

The file should be created successfully, and you can see it visibly in the `/mnt/zdata` folder in dolphin.
Modify the access permission to the ZFS pool to allow the current user to write to it, by running the following command:

`sudo chmod 777 /mnt/zdata`

Rightclick in the empty space and see if `+ Create New` is available, it should nolonger be greyed. Test it!

#### Checking the health of the ZFS pool and drives

In Konsole type `zfs list`
you should see  something like this:

```shell
NAME        USED  AVAIL  REFER  MOUNTPOINT
zdata      1.61G  28.9T   153K  none
zhdd/zdata  288K  28.9T   288K  /mnt/zdata
```

In Konsole type `zfs status -v zhdd`
you should see  something like this:

```shell
pool: zhdd
 state: ONLINE
status: Some supported and requested features are not enabled on the pool.
        The pool can still be used, but some features are unavailable.
action: Enable the features using 'zpool upgrade'. Once this is done,
        the pool may no longer be accessible on software that does not support
        the features. See zpool-features(7) for details.
config:

        NAME                            STATE     READ WRITE CKSUM
        zhdd                            ONLINE       0     0     0
          raidz1-0                      ONLINE       0     0     0
            wwn-0x5000c5011.....-part1  ONLINE       0     0     0
            wwn-0x5000c5011.....-part1  ONLINE       0     0     0
            wwn-0x5000c5011.....-part1  ONLINE       0     0     0
            wwn-0x5000c5011.....-part1  ONLINE       0     0     0
            wwn-0x5000c5011.....-part1  ONLINE       0     0     0
error: No known data errors
```

## Minimal Installer

When installing using the minimal installer, no GUI, there are some particular steps to keep in mind:

- Connecting to WiFi can be done with wpa_cli using the following steps:
  - `sudo systemctl start wpa_supplicant`
  - `wpa_cli`
  - `> scan`
  - `> scan_results`
  - `> add_network 0`
  - `> set_network 0 ssid "<SSID>"`
  - `> set_network 0 psk "<Passphrase>"`
  - `> enable_network 0`
  - `> quit`
- Now to add the Ventoy drive to get the flake for rapid installation:
  - `lsblk`
  - `mount -l`
  - `sudo mkdir /tmp/ventoy`
  - `sudo mount /dev/mapper/sda1 /tmp/ventoy`
- Cat this document as a reference for the actual installation:
  - `cat /tmp/ventoy/git/docs/disko-install.md`

## Linux Bootmanager

If re-installing on a device with prior (Linux) bootmanager instances, use the following commands to delete prior/obsolete Linux Bootmanager registrations in the device NVRAM:

1. Determine which bootnum `Boot000x` registration is no longer needed:
    - `sudo efibootmgr -v`
2. This deletes that specific boot registration:
    - `sudo efibootmgr -b <bootnum> -B`

## Remote logon SSH with password

In order to be able to logon remotely to a NixOS installer machine (to enter remotely to perform the nixos-install steps), do the following:

- Login to the console (via Proxmox Console, or directly to the hardware console)
- Type `passwd`
- Type in a new password, twice to verify
- Login to the machine remotely using `ssh nixos@<machine-ip-address>`
- Start the installation (using Disko if preferred) from the commandline as normal

## Remote logon with SSH keys / no password

In order to be able to logon to NixOS installer machines remotely, ensure the following steps:

- On your local machine ensure you have a public/private SSH key pair, something like:
  - `ssh-keygen -t ed25519 -C "mike+homelab@bearman.nl" -f ~/.ssh/authentication-homelab-mike-pc-vm-nixos-wsl`
- Copy the public key, which you can print out with the following:
  - `cat ~/.ssh/authentication-homelab-mike-pc-vm-nixos-wsl.pub`
- Either pre-provision the public key by adding the previous public key to the openssh keys for the nixos users, or directly on the host manually:
  - Login to the console (via Proxmox Console, or directly to the hardware console)
  - `mkdir -p ~/.ssh && chmod 700 ~/.ssh"`
  - `touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys`
  - Paste the earlier generated public key into the `~/.ssh/authorized_keys file`
  - Logout of the console locally.
- On your machine that you will remote from, don't forget to run, `ssh-add ~/.ssh/authentication-homelab-mike-pc-vm-nixos-wsl` (that's the private file, not the pub file). You will be prompted for a password here, if you added one at creation of the key
- Login to the host using `ssh@<remote-ip>` and it will now authenticate using the public/private key combination

You can now login to those nixos installer images without using passwords!

> Don't forget to ssh-add your key every boot, or automate that process somehow.

## Copy the NixOS Flake & disk-configuration to remote

In order to ensure the disk-configuration and complete flake are available for install do the following:

- Ensure remote SSH access is enabled
- Run `scp -r /path/to/flake nixos@<machine-ip-address>:/tmp/flake-install`
- Start installation from the commandline install steps using the now locally availabel flake and disk-configuration
