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
