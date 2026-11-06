# Generic NixOS Modules Library by TheCloudExplorers

An engineering-first standard library of NixOS modules designed to separate **Infrastructure Policy** (the *how*) from **User Configuration** (the *what*).

Instead of sprawling, monolithic configuration files, this project provides "Blocks"—isolated, versioned modules that handle complex system wiring. Downstream users simply provide a minimal set of parameters to activate production-ready services.

## 🏗 Architecture Philosophy: The Contract

Every module in this library follows a **Contract-Based** design pattern:

1. **The Library (This Repo):** Contains the NixOS modules and logic required for complex behavior (e.g., Secure Boot, TPM sealing, IDM integrations).
2. **The Consumer (Downstream NixOS Config):** Only provides the raw data (Usernames, GIDs, Paths, Toggles).

By isolating configuration from implementation, we ensure that common infrastructure remains consistent across multiple personal and professional deployments.

## 🛠 Component Overview

### 1. Modules (`/modules`)

Standardized, declarative Nix code for specific features:

- **Boot:** Secure Boot + TPM auto-unlock (via Lanzaboote).
- **User:** Defaultizing system accounts with automatic UID/GID mapping.
- **IDM:** Kanidm integrations.
- **Networking:** Dedicated profiles for standardized connectivity.

### 2. Provisioning (`/provisioning`)

NixOS is declarative, but hardware state (like TPM sealing) can be imperative. To ensure a "care-free" user experience, we provide Ansible playbooks that handle one-time setup tasks:

- **Secure Boot Key Enrollment**
- **TPM PCR Sealing**
- **Firmware verification checks**

---

## 🚀 Quick Start: Secure Boot & TPM Unlock

This example shows how a consumer adopts the `secureboot-tpm` block.

### Step 1: Nix Configuration

The downstream config is reduced to just identifying the inputs and passing values into the module:

With a flake, declare the `lanzaboote` input and pass the flake inputs to the modules via `specialArgs` (see `examples/personal-flake.nix`):

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

Without a flake, provide the `inputs` module argument via `specialArgs` at the `nixosSystem` entrypoint (see `examples/personal-config.nix` for the full wiring). The downstream config is then reduced to importing the module and passing values into its declared options:

```nix
# examples/personal-config.nix
{
  imports = [
    ./../modules/boot/secure-boot-tpm.nix
  ];

  # Only provide the 'parameters' - the module handles
  # kernel modules, initrd settings, and bootloader flags.
  # Defaults: enable = true, pkiBundle = "/var/lib/sbctl".
  services.common_modules.secureBoot = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
}
```

### Step 2: One-Time Provisioning

After the first build and boot, run the provisioning playbook to seal your hardware state. This replaces manual documentation with a reproducible script.

```bash
# Enter the directory
cd provisioning
# Run the local provision playbook
ansible-playbook site.yml --become
```

## 🗺 Roadmap

- [x] Localization modules (C, EU, NL)
- [x] Secure Boot + TPM Unlock (Lanzaboote block)
- [ ] Default User Block (Name/GID wiring)
- [ ] IDM / Kanidm Services
- [ ] AI Workloads & Hermes Agent integration
- [ ] Collaboration modules (Nextcloud, etc.)

## License

- **Code and tools:** GPL-3.0.
- **Spec and documentation text:** CC-BY-SA-4.0. Use and adapt freely, including
  commercially and internally; attribution required; adaptations must be
  shared under the same license. Internal adoption is unaffected — ShareAlike
  obligations apply only when you distribute an adapted version.
