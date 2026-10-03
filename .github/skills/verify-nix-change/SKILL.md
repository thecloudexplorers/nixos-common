---
name: verify-nix-change
description: Format and verify changes to Nix files in this NixOS flake repo. Use after editing any .nix file, before reporting a change as done.
---

# Verify a Nix change

Run from the repo root. Use `nix develop` to get `nixfmt` and `nixd`.

1. **Track new files**: flakes only see files known to git. Run `git add <new files>` for any new `.nix` file.
2. **Format** every changed file:
   ```sh
   nixfmt <changed .nix files>
   ```
3. **Evaluate the flake**:
   ```sh
   nix flake check
   ```
4. **Dry-run build the server** (evaluates all containers without building):
   ```sh
   nix build .#nixosConfigurations.faml-pc-home_server.config.system.build.toplevel --dry-run
   ```

## If a step fails

- Read the error and fix the cause, then re-run from the failing step.
- An unknown option usually means a wrong name. Check it for nixpkgs 26.05 (search.nixos.org/options?channel=26.05); do not guess.
- A container cannot reference host options, and the reverse. Each evaluates separately.
- Do not silence errors, remove checks, or add `lib.mkForce` to dodge a conflict without understanding it.

## Never run

`nixos-rebuild switch`, `nixos-install`, `disko`, or anything that changes the running system or disks. Tell the user which command to run and ask them to paste the output. Never ask for a sudo password.

## Report

State which steps passed. If a step could not be run, say so instead of claiming success.
