# Generic NixOS Modules Library by TheCloudExplorers

## 📜 Context & Philosophy

This repository serves as the primary infrastructure accelerator for
`TheCloudExplorers`. Beyond its role as an internal standard, it is designed as
a *modern reference architecture* for the NixOS community.

Inspired by the principles of
[Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/overview/introduction/),
we aim to provide a "single definition" of what a high-quality NixOS module is:

- *Consistency*: Standardized construction and testing (see roadmap) across
all modules.
- *Contract-Based*: Strict separation of infrastructure policy (the how) from
user configuration (the what).
- *Reliability*: Production-ready "plumbing" that lets users focus on their
workloads rather than system wiring.

Instead of sprawling, monolithic configuration files, this project provides
versioned modules that handle the complex system wiring.

## 🏗 Architecture: The Contract

Every module in this library follows a **Contract-Based** design pattern:

1. **The Library (This Repo):** Contains the NixOS modules and logic required
for complex behavior (e.g., Secure Boot, TPM sealing, IDM integrations).
2. **The Consumer (Downstream NixOS Config):** Only provides the raw data
(Usernames, GIDs, Paths, Toggles).

All options this library declares live under `tce.services.common-modules.*`,
`tce` abbreviates TheCloudExplorers, so the namespace can never collide with
upstream NixOS options — and use dashes (not underscores) per NixOS attribute
conventions. Isolating configuration from implementation keeps common
infrastructure consistent across all downstream deployments.

## 🧩 Component Overview

### 1. Modules (`/modules`)

Standardized, declarative Nix code for specific features:

- **Boot:** Secure Boot + TPM auto-unlock (via Lanzaboote).
- **Nix base:** Substituters, GC/optimise, automatic upgrades, nixpkgs
platform/unfree defaults (`nix-base` module).
- **User:** Defaultizing system accounts with automatic UID/GID mapping.
- **IDM:** Kanidm integrations.
- **Networking:** Dedicated profiles for standardized connectivity.

### 2. Provisioning (`/provisioning`)

NixOS is declarative, but hardware state (like TPM sealing) can be
imperative. To ensure a "care-free" user experience, we provide Ansible
playbooks that handle one-time setup tasks:

- **Secure Boot Key Enrollment**
- **TPM PCR Sealing**
- **Firmware verification checks**

---

## 🚀 Quick Start: Secure Boot & TPM Unlock

This example shows how a consumer adopts the `secureboot-tpm` module. For the
full guide — first-time key enrollment, TPM auto-unlock of encrypted drives,
PCR selection, and re-enrollment after firmware/key changes — see
[docs/secure-boot.md](docs/secure-boot.md).

### Step 1: Nix Configuration

The downstream config is reduced to just identifying the inputs and passing
values into the module:

With a flake, declare the `lanzaboote` input and pass the flake inputs to the
modules via `specialArgs` (see `examples/personal-flake.nix`):

```nix
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit (self) inputs outputs; };
  modules = [
    nixos-common.nixosModules.secure-boot-tpm
    ./configuration.nix
  ];
}
```

Without a flake, provide the `inputs` module argument via `specialArgs` at
the `nixosSystem` entrypoint (see `examples/personal-config.nix` for the full
wiring). The downstream config is then reduced to importing the module and
passing values into its declared options:

```nix
# examples/personal-config.nix
{
  imports = [
    ./../modules/boot/secure-boot-tpm.nix
  ];

  # Only provide the 'parameters' - the module handles
  # kernel modules, initrd settings, and bootloader flags.
  # Defaults: enable = true, pkiBundle = "/var/lib/sbctl".
  tce.services.common-modules.secureBoot = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
}
```

### Step 2: One-Time Provisioning

After the first build and boot, run the provisioning playbook to seal your
hardware state. This replaces manual documentation with a reproducible script.

```bash
# Enter the directory
cd provisioning
# Run the local provision playbook
ansible-playbook site.yaml --become
```

## 🧱 Nix Base Settings

The `nix-base` module applies base Nix/NixOS settings: substituters and
trusted keys, garbage collection, store optimisation, automatic upgrades, and
the nixpkgs platform/unfree defaults. Every value is a declared option with a
default, so consumers only override what they need:

```nix
# In the modules list:
nixos-common.nixosModules.nix-base

# Optional overrides (defaults shown):
# tce.services.common-modules.nixBase = {
#   trustedUsers = [ "@wheel" ];
#   gc.options = "--delete-older-than 14d";
#   autoUpgrade.enable = false;
#   stateVersion = "26.05";
# };
```

## </> Developing with a local clone

To test uncommitted changes to this repo from a consumer flake (or fork),
see [docs/dev-flow.md](docs/dev-flow.md) — the `--override-input` workflow
for evaluating/building against a local checkout without pushing.

## 🗺 Roadmap

- [x] Nix base settings (`nix-base` module: substituters, GC, auto-upgrade,
stateVersion)
- [x] Localization modules (C, EU, NL)
- [x] Secure Boot + TPM Unlock (Lanzaboote module)
- [ ] Default User module (Name/GID wiring)
- [ ] IDM / Kanidm Services
- [ ] AI Workloads & Hermes Agent integration
- [ ] Collaboration modules (Nextcloud, etc.)
  - [ ] Designed as turn-key accelerators for solutions/patterns like a
  "federated Nextcloud Talk stack" (HPB + NATS + TURN):
  [docs/nextcloud-talk-federation.md](docs/nextcloud-talk-federation.md)
- [ ] Implement testing for each module

## ⚖️ License

- **Code and tools:** GPL-3.0.
- **Spec and documentation text:** CC-BY-SA-4.0. Use and adapt freely, including
  commercially and internally; attribution required; adaptations must be
  shared under the same license. Internal adoption is unaffected — ShareAlike
  obligations apply only when you distribute an adapted version.

## 🛠️ Use of AI Tools

For full transparency: this repository is primarily human-coded and
human-documented, with AI assistance. AI coding agents (e.g. Microsoft
Copilot, Mistral Vibe) are used deliberately for editing, refactoring,
drafting, and documentation — building on and expanding human-written
foundations. Every AI-assisted change is read, understood, reviewed, and
approved by a human maintainer before it lands. The architecture, the design
decisions, and the codebase as a whole remain human work, and a human is
accountable for all of it.

We deliberately distinguish this from "vibe coding" in the pejorative sense:
handing full autonomy to a tool without understanding what it produces. A
fool with a tool is still a fool — capable models amplify expertise, judgment,
and standards; they do not replace them. If something here is buggy or
broken, a human owns that and a human will fix it.
