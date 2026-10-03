---
name: add-workload-node
description: Add a new node (e.g. container-2) to an existing workload in this NixOS repo, or create a new workload. Use when asked to add a node, replica, container or workload/service container.
---

# Add a workload node or workload

Read `modules/workload/README.md` first; it defines the file conventions.

## New node of an existing workload

1. Copy `modules/workload/<name>/container-1/` to `container-<N>/`.
2. Rename the files: `container-<N>.nix`, `networking-<N>.nix`.
3. In both files change `workloadNode = <N>;` and everything built from it.
4. In `networking-<N>.nix` set a new, unique:
   - `computerId` (hostId). Generated with `head -c 8 /etc/machine-id` on a fresh machine id; it only needs to be unique.
   - MAC address (`ethernetInterfaceMacAddress`), where the sibling node sets one.
   - Static `extraHosts` entries only where the sibling has them.
5. Add `container-<N>/service-<service>-<N>.nix` only when settings differ from the siblings (see `heartstone/container-1/service-kanidm-1.nix` for an example). Shared settings stay in `service-<service>.nix`.
6. In `host-data.nix`, add the `systemd.tmpfiles` rules for the new node's bind mount directories (paths use `${toString workloadNode}`).
7. Import the new `container-<N>.nix` (and `host-data.nix` if the workload is new) in `modules/computer/server/faml-pc-home_server/configuration.nix`, under "Workloads to be hosted on this server".
8. Update the workload's `README.md` and, if the workload is new, the table in `modules/workload/README.md`.

## New workload

Copy a similar workload. `modules/workload/dalaran/` is the reference for bind mounts and secrets. Rename `workloadName`, `workloadService`, and keep the file names from the README: `workload.nix`, `service-<name>.nix`, `host-data.nix`, `container-1/`.

## Always tell the user

- The new node needs a **DHCP reservation** on the router for its MAC address.
- Anything that depends on the old IP (nginx in `baleroc`, `extraHosts`, DNS) must be updated by hand.

## Never

- Change `system.stateVersion` of an existing workload.
- Reuse a MAC address or hostId from another node.

Then follow the `verify-nix-change` skill.
