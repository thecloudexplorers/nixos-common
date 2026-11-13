# Secure Boot and TPM Auto-Unlock

Secure Boot is provided by the `secure-boot-tpm` module from
[nixos-common](https://github.com/thecloudexplorers/nixos-common), imported in `flake.nix`
(`nixos-common.nixosModules.secure-boot-tpm`). The module takes care of the Nix side:

- importing the `lanzaboote` NixOS module (the `lanzaboote` flake input in this repo is required),
- enabling bootspec,
- enabling lanzaboote and disabling `systemd-boot`,
- setting the PKI bundle location (`/var/lib/sbctl` by default),
- installing `sbctl`, `tpm2-tools` and `tpm2-tss`.

So there is no need to configure lanzaboote, bootspec or `systemd-boot` in this repo. What remains are
the manual steps on the machine, described below.

## Creating the signing keys during a greenfield install

The keys must exist before the bootloader is installed, otherwise lanzaboote fails with
`Failed to read public key from /var/lib/sbctl/keys/db/db.pem`. While installing from the installer, the
target system is mounted on `/mnt`, so create the keys there, before running `nixos-install`:

- `nix --experimental-features "nix-command flakes" shell nixpkgs#sbctl -c sudo sbctl --database-path /mnt/var/lib/sbctl create-keys`
- Validate that `/mnt/var/lib/sbctl/keys/db/db.pem` exists.

Then continue with the remaining steps below after the first boot.

## Steps to ensure Secure Boot works after install

1. Create the signing keys (they end up in the PKI bundle, `/var/lib/sbctl` by default):
    - `nix shell nixpkgs#sbctl -c sudo sbctl create-keys` (`sbctl` is only on the PATH after the first successful switch, so use `nix shell` here)
    - Check they exist: `sudo tree /var/lib/sbctl`
2. Rebuild and switch the configuration (this signs the boot files with the keys):
    - Hand this to the person with sudo rights, for example `sudo nixos-rebuild switch --flake .#faml-pc-home_server`
3. Verify that the boot files are signed:
    - `sudo sbctl verify`
    - One line for `/boot/EFI/nixos/kernel-*.efi` showing "is not signed" is expected: lanzaboote only signs
      the UKIs and the systemd-boot stub, and the unsigned kernel is verified through the hash embedded in the UKI.
4. Put the firmware in Secure Boot *setup mode*, then enroll the keys (including the Microsoft keys, so
   firmware option ROMs keep working):
    - In the BIOS (ASUS ProArt X870E-Creator WiFi) go to **Boot** → **Secure Boot** → **Key Management** and
      choose **Clear Secure Boot Keys**, then save and exit.
    - Back in NixOS, check `sudo sbctl status` shows `Setup Mode: ✓ Enabled`.
    - `sudo sbctl enroll-keys --microsoft`
5. Reboot and enable Secure Boot in the firmware:
    - In the BIOS, under **Boot** → **Secure Boot**, set **OS Type** to **Windows UEFI mode**.
      > NOTE: **Other OS** leaves Secure Boot disabled, even with the keys enrolled. Do not use
      > "Install default Secure Boot keys", as that overwrites the enrolled keys.
    - Save and exit, then check `sudo sbctl status` (`Secure Boot: ✓ Enabled`) and `sudo bootctl status`
      (`Secure Boot: enabled (user)`).

## TPM auto-unlock of encrypted drives with Secure Boot enabled

Enroll the crypt key into the TPM, allowing automatic unlock. It is tied to Secure Boot, so the OS will not
unlock if Secure Boot fails or is tampered with.

Additionally, create a recovery key, so the drive is still unlockable if all else fails.

The following PCRs are used:

- PCR 0: [UEFI Boot Component] Core system firmware executable code
- PCR 2: [UEFI Boot Component] Extended or pluggable executable code; includes option ROMs on pluggable hardware
- PCR 7: [UEFI Boot Component] SecureBoot state
- PCR 12: [UEFI Stub] Kernel command line, system credentials, system configuration images, initrd addons, µcode addons, devicetree addons

Refer to the [Linux TPM PCR Registry documentation](https://uapi-group.org/specifications/specs/linux_tpm_pcr_registry/)
for more detailed explanations.

1. Enroll the TPM, replacing any existing TPM slot:
    - `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+12 --wipe-slot=tpm2 /dev/nvme0n1p1`
2. Create a recovery key (store it somewhere safe, outside this machine):
    - `sudo systemd-cryptenroll --recovery-key /dev/nvme0n1p1`

### When keys or firmware change

TPM auto-unlock will not work when the measured state changes (for example the Secure Boot state, after
updating keys or the firmware). This is intended, but it means you need to:

1. Disable Secure Boot and enroll the keys again;
2. then enable Secure Boot;
3. then enroll the TPM again (step 1 above).

## Auto-unlock of the encrypted ZFS pool (zhdd)

The `zhdd/zdata` dataset uses native ZFS encryption, not LUKS, so the TPM cannot unlock it directly.
Instead its passphrase is stored in a file on the root drive, which is LUKS encrypted and unlocked by the TPM.
The file is only readable after Secure Boot and the TPM have unlocked the root. `disko-config.nix` points
`keylocation` at `file:///var/lib/zfs/secret.key`; the file itself is created manually and never ends up in
the Nix store.

1. Create the key file with the current dataset passphrase, without a trailing newline (ZFS reads the whole
   file as the passphrase):
    - `sudo install -d -m 0700 /var/lib/zfs`
    - `sudo sh -c "printf '%s' '<passphrase>' > /var/lib/zfs/secret.key"`
    - `sudo chmod 0400 /var/lib/zfs/secret.key`
2. Tell the existing dataset where to find the key (`keylocation` in disko only applies to new datasets):
    - `sudo zfs set keylocation=file:///var/lib/zfs/secret.key zhdd/zdata`
3. Check that the key loads from the file:
    - `sudo zfs unmount zhdd/zdata && sudo zfs unload-key zhdd/zdata`
    - `sudo zfs load-key zhdd/zdata && sudo zfs mount zhdd/zdata`
4. Rebuild and reboot; the passphrase prompt for `zhdd` should no longer appear.

The passphrase still works as a manual fallback, for example if the key file is lost.

### Recovery and safety for the ZFS key

ZFS has no recovery key slot like LUKS: an encrypted dataset has exactly one key. The setup above is safe
because it never changes that key; the key file contains the existing passphrase.

- Store the passphrase in a password manager before you start. It is the recovery key, and it is also what
  unlocks the pool on a new system if the root drive (and with it the key file) is lost.
- `zfs set keylocation=...` only changes a property, not the encrypted data or the key. Revert it with
  `sudo zfs set keylocation=prompt zhdd/zdata`, after which the boot prompt and the passphrase work again.
- If loading from the file fails, load the key manually with `sudo zfs load-key -L prompt zhdd/zdata`.
- Do not use `zfs change-key` for this setup. It is the command that can lock you out of the dataset.
- Before starting, save the output of `sudo zfs get keystatus,keylocation,encryptionroot zhdd/zdata` so you
  know the starting state, and run the load-key test (step 3) before rebooting.
