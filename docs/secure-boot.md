# Secure Boot & TPM Auto-Unlock

This guide describes how to set up UEFI Secure Boot with automatic TPM-based
unlocking of encrypted drives, using the `secure-boot-tpm` module from this
repository. It expands the one-time provisioning steps into a complete,
repeatable procedure.

- [How it fits together](#how-it-fits-together)
- [Requirements](#requirements)
- [NixOS configuration](#nixos-configuration)
  - [With a flake](#with-a-flake)
  - [Without a flake](#without-a-flake)
  - [Module options](#module-options)
  - [What the module configures for you](#what-the-module-configures-for-you)
- [First-time provisioning](#first-time-provisioning)
- [TPM auto-unlock of encrypted drives](#tpm-auto-unlock-of-encrypted-drives)
  - [Choosing PCRs](#choosing-pcrs)
  - [Sealing the LUKS key into the TPM](#sealing-the-luks-key-into-the-tpm)
  - [Adding a recovery key](#adding-a-recovery-key)
- [Re-enrollment after changes](#re-enrollment-after-changes)
- [Troubleshooting](#troubleshooting)
- [References](#references)

## How it fits together

| Component | Role |
| --- | --- |
| [Lanzaboote](https://github.com/nix-community/lanzaboote) | Bootloader that turns each NixOS generation into a signed Unified Kernel Image (UKI) and installs it on the ESP. |
| [sbctl](https://github.com/Foxboron/sbctl) | Creates and manages the Secure Boot PKI (db, KEK, PK) and enrolls it into the UEFI firmware variables. |
| [Boot Loader Specification](https://uapi-group.org/specifications/specs/boot_loader_specification/) / bootspec | Standardized boot entries; `boot.bootspec.enableValidation` makes NixOS validate them. |
| TPM2 + `systemd-cryptenroll` | Seals the LUKS volume key into the TPM, bound to Platform Configuration Registers (PCRs), so the drive unlocks automatically only when the boot chain is in an expected state. |

The idea: Secure Boot guarantees that only signed boot components run
(PCR 7 reflects this state), and the TPM only releases the disk key when the
measured boot state (PCRs) matches the state at enrollment time. If firmware,
Secure Boot keys, or the kernel command line change, the TPM refuses to
unlock and you fall back to the recovery key.

## Requirements

- x86_64 machine with UEFI firmware (not BIOS/legacy boot) and a TPM2 chip.
- An EFI System Partition (ESP), by convention mounted at `/boot` on NixOS
  (`boot.loader.efi.efiSysMountPoint`). Verify with `bootctl status` — the
  output should show `ESP:`.
- A `lanzaboote` input in your flake (see below), or a fetched copy of the
  lanzaboote repository when not using flakes.
- Secure Boot **disabled** in the firmware for the initial install (many
  firmwares call this "Setup Mode"); it is enabled by enrolling keys.

## NixOS configuration

### With a flake

See `examples/personal-flake.nix`. The essential parts:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-common.url = "github:thecloudexplorers/nixos-common/main";
  };

  outputs = { self, nixpkgs, nixos-common, ... }:
    {
      nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # The module reads `inputs.lanzaboote` from the module arguments,
        # so the flake inputs must be passed through as specialArgs.
        specialArgs = { inherit (self) inputs; };
        modules = [
          nixos-common.nixosModules.secure-boot-tpm
          ./configuration.nix
        ];
      };
    };
}
```

### Without a flake

See `examples/personal-config.nix`. Because NixOS `imports` cannot depend on
`config`, the `inputs` argument cannot be provided via `_module.args` from
within a configuration module; pass it as `specialArgs` at the entrypoint
instead:

```nix
# default.nix
let
  lanzabooteSrc = builtins.fetchGit {
    url = "https://github.com/nix-community/lanzaboote.git";
    rev = "<commit-hash>";
  };
in
(import <nixpkgs> { }).lib.nixosSystem {
  modules = [ ./personal-config.nix ];
  specialArgs.inputs.lanzaboote.nixosModules.lanzaboote =
    import "${lanzabooteSrc}/nix/modules/lanzaboote.nix";
}
```

and in `personal-config.nix`:

```nix
{
  imports = [
    # One line imports the whole 'block'.
    "${builtins.fetchGit { url = "https://github.com/thecloudexplorers/nixos-common.git"; rev = "<commit-hash>"; }}/modules/boot/secure-boot-tpm.nix"
  ];
}
```

### Module options

The module declares its contract as standard NixOS options under
`tce.services.common-modules.secureBoot`:

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `tce.services.common-modules.secureBoot.enable` | bool | `true` | Master switch for the whole block. |
| `tce.services.common-modules.secureBoot.pkiBundle` | path | `"/var/lib/sbctl"` | Directory holding the sbctl PKI (`keys/`, `GUID`). Must match where `sbctl create-keys` put the keys. Override example: `tce.services.common-modules.secureBoot.pkiBundle = "/etc/secureboot";` (older sbctl default). |

### What the module configures for you

When `enable = true`, the module sets:

- `boot.lanzaboote.enable = true` and `boot.lanzaboote.pkiBundle` from the
  option above — Lanzaboote becomes the bootloader and signs every
  generation.
- `boot.bootspec.enableValidation = true` — NixOS validates the Boot Loader
  Specification entries.
- `boot.loader.systemd-boot.enable = false` and `boot.loader.grub.enable = false`
  — Lanzaboote replaces both. (The explicit grub disable matters on
  nixos-26.05, where `boot.loader.grub.enable` defaults to
  `!boot.isContainer`; with systemd-boot off, nothing else would turn grub
  off and its "set `devices`" assertion would fail the build.)
- `boot.loader.efi.canTouchEfiVariables = true` — needed to enroll keys from
  Linux.
- `boot.initrd.availableKernelModules` += `encrypted_keys`, `tpm`, `trusted`
  — kernel modules needed for TPM-based unlocking in the initrd.
- `environment.systemPackages` += `sbctl`, `tpm2-tools`, `tpm2-tss`.

## First-time provisioning

Do this **after** the first `nixos-rebuild switch` with the module enabled,
while Secure Boot is still disabled in the firmware:

```bash
# 1. Create the Secure Boot keys (stored in /var/lib/sbctl by default)
sudo sbctl create-keys

# 2. Inspect the key tree
sudo tree /var/lib/sbctl        # (or: ls -R /var/lib/sbctl)

# 3. Verify that all currently booted components are signed correctly
sudo sbctl verify

# 4. Enroll your keys into the UEFI variables, including Microsoft's keys
#    (so that e.g. Windows dual-boot and some firmware option ROMs still verify)
sudo sbctl enroll-keys --microsoft

# 5. Check the bootloader status
sudo bootctl status
```

Then reboot and **enable Secure Boot in the UEFI settings**. On the next boot
you should see Lanzaboote's boot menu (or an automatic boot), and
`sudo sbctl status` should report Secure Boot as enabled.

> Prefer automation? `provisioning/site.yaml` is an Ansible playbook that
> performs these steps plus the TPM sealing below. Edit
> `provisioning/variables.yaml` first (`encrypted_device`, `tpm_pcrs`), then:
>
> ```bash
> cd provisioning
> ansible-playbook site.yaml --become -K
> ```

## TPM auto-unlock of encrypted drives

The LUKS volume key is sealed into the TPM, bound to a set of PCRs. The TPM
only unseals it when the current PCR values match the enrolled ones — i.e.
when the firmware, Secure Boot state, and kernel command line are in the
exact state they were in at enrollment.

### Choosing PCRs

This repository seals to **PCR 0+2+7+12** (see `provisioning/variables.yaml`).
Per the [Linux TPM PCR Registry](https://uapi-group.org/specifications/specs/linux_tpm_pcr_registry/):

| PCR | Measures | Changes when |
| --- | --- | --- |
| 0 | Core system firmware executable code (SRTM/BIOS) | Firmware updates |
| 2 | Extended/pluggable executable code (option ROMs) | Adding/changing add-in cards, some firmware updates |
| 7 | Secure Boot state: policy, db/KEK/PK certificates | Enrolling/revoking Secure Boot keys, toggling Secure Boot |
| 12 | Kernel command line, system credentials, initrd addons, µcode addons, devicetree addons (measured by systemd-boot / the UEFI stub) | Kernel command line changes, initrd addons |

PCR 7 is the one that ties unlocking to Secure Boot: if the Secure Boot state
changes, the TPM refuses to unseal — which is intended here.

Note: PCR 11 (used by `systemd-stub` for the kernel image + embedded initrd)
is deliberately **not** used, because it changes on every kernel update. If
you *do* want update-friendly sealing, look at `--tpm2-public-key-pcrs=`
(default PCR 11) in `systemd-cryptenroll(1)`, which binds to signed PCR
policies instead of raw PCR values.

### Sealing the LUKS key into the TPM

```bash
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+12 --wipe-slot=tpm2 /dev/<device>
```

- `--tpm2-device=auto` lets systemd pick the TPM automatically.
- `--wipe-slot=tpm2` replaces any previous TPM enrollment on the volume.
- `/dev/<device>` is the LUKS partition, e.g. `/dev/nvme0n1p3`.

Make sure the matching `crypttab` entry uses the TPM, e.g.:

```
# /etc/crypttab
myvolume /dev/nvme0n1p3 none tpm2-device=auto
```

(On NixOS, set this via `boot.initrd.luks.devices.<name>.device = ...;` and
`...crypttabExtraOpts = [ "tpm2-device=auto" ];`.)

### Adding a recovery key

Always enroll a recovery key as a safety net — if the PCRs change and the
TPM refuses to unlock, this is your way back in:

```bash
sudo systemd-cryptenroll --recovery-key /dev/<device>
```

Store the printed recovery key somewhere safe (password manager, printed
copy). It unlocks the volume regardless of PCR state.

## Re-enrollment after changes

Because PCRs 0, 2, 7 and 12 are bound, the TPM auto-unlock **stops working**
after, for example, a firmware update, a Secure Boot key change, or a kernel
command line change. This is by design. When it happens:

1. Boot and unlock with the **recovery key** (or temporarily disable Secure
   Boot / boot a live USB).
2. Fix the underlying change.
3. Re-seal the TPM slot to the new state:

   ```bash
   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+12 --wipe-slot=tpm2 /dev/<device>
   ```

If you rotate Secure Boot keys, the full cycle is:

1. Disable Secure Boot in the UEFI settings, boot.
2. `sudo sbctl create-keys` (if generating new keys) and
   `sudo sbctl enroll-keys --microsoft`.
3. Re-enable Secure Boot in the UEFI settings.
4. Re-seal the TPM as above (PCR 7 changed).

## Troubleshooting

- `sudo sbctl status` — shows whether Secure Boot is enabled and which keys
  are enrolled.
- `sudo sbctl verify` — verifies that all boot components on the ESP are
  correctly signed. If it reports unsigned files, re-enroll or re-sign.
- `sudo bootctl status` — shows the bootloader, ESP mount point, and current
  boot entry. The ESP line confirms your ESP is detected.
- Boot failure right after enabling Secure Boot: the firmware likely did not
  accept the keys. Re-enter UEFI settings, make sure you are not in "Setup
  Mode" anymore, and re-run `sbctl enroll-keys --microsoft`. As a last resort,
  disable Secure Boot to boot, then investigate with `sbctl status`.
- After a firmware update the drive no longer auto-unlocks: expected — see
  [Re-enrollment after changes](#re-enrollment-after-changes).

## References

- Lanzaboote repository: <https://github.com/nix-community/lanzaboote>
- Lanzaboote documentation: <https://nix-community.github.io/lanzaboote/>
- sbctl (Secure Boot key manager): <https://github.com/Foxboron/sbctl>
- `systemd-cryptenroll(1)` — TPM2 enrollment, PCR binding, recovery keys:
  <https://www.freedesktop.org/software/systemd/man/latest/systemd-cryptenroll.html>
- `crypttab(5)` — the `tpm2-device=` option:
  <https://www.freedesktop.org/software/systemd/man/latest/crypttab.html>
- UAPI.7 Linux TPM PCR Registry (authoritative PCR meanings):
  <https://uapi-group.org/specifications/specs/linux_tpm_pcr_registry/>
- Boot Loader Specification:
  <https://uapi-group.org/specifications/specs/boot_loader_specification/>
- Arch Wiki — Secure Boot (useful background and firmware quirks):
  <https://wiki.archlinux.org/title/Secure_Boot>
