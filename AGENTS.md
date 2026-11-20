# AGENTS.md

Guidance for AI coding agents (Copilot, Claude, Gemini, Cursor, Codex, etc.).
This is the single source of truth; tool-specific files only point here.

## What this repo is

A NixOS flake (`flake.nix`, nixpkgs `nixos-26.05`, `stateVersion = "26.05"`)
for a home server, `faml-pc-home_server`. The server hosts services as
declarative NixOS containers ("workloads"). Also contains USB installer
generators and docs.

## Layout

- `flake.nix`: inputs, installer images, devShell (`nixd`, `nixfmt`), `nixosConfigurations`.
- `modules/computer/server/faml-pc-home_server/`: host config (`configuration.nix`, `disko-config.nix`, `hardware-configuration.nix`, `networking.nix`). `configuration.nix` imports every workload.
- `modules/workload/<name>/`: one workload per service (see the table in [modules/workload/README.md](modules/workload/README.md) for the current list). **Read [modules/workload/README.md](modules/workload/README.md) before touching workloads**; it defines the file conventions.
- `modules/users/`, `modules/networking/`, `modules/nix/`, `modules/services/`: shared modules.
- `docs/`: install and operations docs. `scripts/`: helper scripts. `generators/`: installer ISOs.

## Conventions

- All workload names, and therefore their container names, must be inspired by
  World of Warcraft lore. Choose a character, place, or other reference whose
  role or story is as close as possible to the workload's purpose; avoid
  arbitrary or unrelated names. For example, `baleroc` is a fitting name for
  the externally facing nginx reverse proxy because Baleroc is known as the
  Gatekeeper.
- Workload file naming: `workload.nix`, `service-<name>.nix`, `host-data.nix`, `container-<N>/container-<N>.nix`, `container-<N>/networking-<N>.nix`, `container-<N>/service-<name>-<N>.nix` (only when a node differs).
- Shared service config goes in `service-<name>.nix`; node-specific settings only in the per-node file.
- Host-side bind mount dirs/permissions go in `host-data.nix` (`systemd.tmpfiles`), not inside containers.
- A new node/workload must be imported in the server's `configuration.nix`, needs a unique MAC address, and a DHCP reservation (mention this to the user).
- Never change `system.stateVersion` / `stateVersion` of existing systems.
- Keep each workload's `README.md` and the table in `modules/workload/README.md` in sync with changes.
- Keep comments explaining the "why"; match the existing commented style.
- Use relative imports like the existing files.

## Templates (copy, do not invent)

- New node of an existing workload: copy `modules/workload/<name>/container-1/` to `container-<N>/`, rename the files, change the node number, MAC address and IP. Add `service-<name>-<N>.nix` only if settings differ.
- New workload: copy a similar one. `modules/workload/dalaran/` is the reference for a service with bind mounts and secrets (`workload.nix`, `service-nextcloud.nix`, `host-data.nix`, `container-1/`).
- Files start with `let workloadName = "<name>"; workloadNode = <N>; in` and build paths from those (`"/mnt/ssd/${workloadName}/${toString workloadNode}/..."`). Keep that pattern.

## Nix style

- Formatter is `nixfmt` (RFC style). Run it on every changed file.
- Module args: `{ ... }:` when unused, otherwise only the ones used (`{ config, lib, pkgs, ... }:`).
- Shared/profile modules (`modules/nix`, `modules/networking`) set defaults with `lib.mkDefault` so hosts can override. Use `lib.mkForce` only when a default must be beaten, and say why in a comment.
- `with pkgs; [ ... ]` is used only for package lists. Do not use `with` elsewhere.
- No `rec`, no `<nixpkgs>` lookups, no `builtins.fetch*` for unpinned content. Inputs go through the flake.
- Prefer the NixOS module option over hand-written systemd units or config files.
- Comment above each non-obvious block or setting, explaining why.

## Security rules

- NEVER put secrets, passwords, tokens, or private keys in Nix files (they end up world-readable in `/nix/store`). Use file-based secrets (e.g. `passwordFile`, `credentialsFile`) pointing at paths outside the store.
- Secrets pattern used here (see `dalaran`): the host keeps the secret in `/mnt/ssd/<workload>/<N>/secrets/<name>/`, created in `host-data.nix` with `systemd.tmpfiles` mode `0700 root root`. `container-<N>.nix` bind mounts it read-only to `/tmp/<workload>-<name>`, and the service option (`adminpassFile`, etc.) points at that path. The user fills in the file manually; document how in `docs/` or the workload README. Never create the secret value yourself.
- Do not commit generated artifacts (`result`, ISO images).
- Do not weaken firewall, TLS, or auth settings without being asked.

## Verify changes

Run from the repo root (devShell: `nix develop`):

```sh
nixfmt <changed .nix files>        # format
nix flake check                    # evaluate the flake
nix build .#nixosConfigurations.faml-pc-home_server.config.system.build.toplevel --dry-run
```

Never run `nixos-rebuild switch`, `nixos-install`, `disko` or anything that
partitions/formats disks or alters the running system; hand those to the user.
Nix files must be tracked by git (`git add`) for flakes to see them.

For changes to sensitive boot-level components (ZFS, disk encryption, initrd,
bootloader, kernel modules, filesystems), tell the user to apply them with
`sudo nixos-rebuild boot --flake .#faml-pc-home_server` (applies on next boot)
instead of `switch`, so a failure cannot break the running system.

## Agent behavior

- Replies: no preamble, no recap, do not restate the diff. Fragments are fine. Code, comments, docs and commit messages stay in normal full prose.
- Make minimal, targeted edits; do not refactor unrelated code.
- Verify option names against the current nixpkgs 26.05 / NixOS options, not memory. Check https://search.nixos.org/options?channel=26.05 (or the module source in nixpkgs `nixos-26.05`). If you cannot verify an option, say so instead of guessing. Run `nix flake check` to catch wrong option names.
- If a verify command fails, fix the cause and re-run; do not silence errors (no `--no-verify`, no deleting checks, no `lib.mkForce` to dodge a conflict without understanding it).
- Container/host config: the server config and each container evaluate separately; inside a container's `config = { ... }` you cannot reference host options.
- Do not create extra markdown docs unless asked; update existing docs instead.
- Never ask the user for a sudo password; ask them to run the command and paste the output.
- Ask before destructive or hard-to-reverse actions (force push, deleting files/branches, disk operations).
