# Workloads

Each workload is a NixOS container (`<name>-<node>`, e.g. `dalaran-1`) running one
service. Per-workload docs and handy commands are in each workload's own README.

| Workload     | Runs                       | README                             |
| ------------ | -------------------------- | ---------------------------------- |
| `baleroc`    | nginx reverse proxy        | [baleroc](baleroc/README.md)       |
| `dalaran`    | Nextcloud                  | [dalaran](dalaran/README.md)       |
| `heartstone` | Kanidm (identity provider) | [heartstone](heartstone/README.md) |
| `ironforge`  | PostgreSQL                 | [ironforge](ironforge/README.md)   |
| `cho`        | Ollama                     | [cho](cho/README.md)               |
| `medivh`     | ACME certificates          | [medivh](medivh/README.md)         |

## Folder structure

```text
<workload>/
  README.md              what runs here + handy commands
  workload.nix           workload-wide config, runs inside every node
  service-<name>.nix     per-service config (one file per service)
  host-data.nix          host side: directories/permissions for bind mounts
  container-<N>/         everything specific to node N
    container-<N>.nix    container definition (bind mounts, network, imports)
    networking-<N>.nix   node network config
    service-<name>-<N>.nix   node specific service config (only when needed)
```

## What each file is for

- **`workload.nix`**: imported inside the container by `container-<N>.nix`. It
  imports the service files, adds shared modules (users, groups) and packages, and
  sets `system.stateVersion`.
- **`service-<name>.nix`**: configuration of one service that is the same on every
  node. It sits directly in the workload folder and is imported from `workload.nix`.
- **`host-data.nix`**: runs on the host (not in the container). It creates the
  bind mount directories with the right owners via `systemd.tmpfiles`. It is
  imported by the server's `configuration.nix`.
- **`container-<N>/container-<N>.nix`**: the container itself. It declares bind
  mounts, the bridge and the imports. It is imported by the server's
  `configuration.nix`.
- **`container-<N>/networking-<N>.nix`**: addressing for that node.
- **`container-<N>/service-<name>-<N>.nix`**: service settings that differ per node.
  Only add this when a node needs different settings than its siblings.

## Per-service config

| Workload     | Shared service config                                      | Node specific service config                                        |
| ------------ | ---------------------------------------------------------- | ------------------------------------------------------------------- |
| `baleroc`    | [service-nginx.nix](baleroc/service-nginx.nix)             | none                                                                |
| `dalaran`    | [service-nextcloud.nix](dalaran/service-nextcloud.nix)     | none                                                                |
| `heartstone` | [service-kanidm.nix](heartstone/service-kanidm.nix)        | [service-kanidm-1.nix](heartstone/container-1/service-kanidm-1.nix) |
| `ironforge`  | [service-postgresql.nix](ironforge/service-postgresql.nix) | none                                                                |
| `cho`        | [service-ollama.nix](cho/service-ollama.nix)               | none                                                                |
| `medivh`     | [acme/](medivh/acme/)                                      | none                                                                |

Notes:

- **heartstone:** `service-kanidm-1.nix` sets `role = "WriteReplica"`, the bind
  addresses, ports and firewall. Kanidm replicates, so these differ per node (a
  second node would be a read replica). Everything shared stays in
  `service-kanidm.nix`: domain, TLS, provisioning of groups, persons and OAuth2
  clients.
- **medivh:** it has several certificates, so its service files are grouped in
  `acme/`. `service-acme.nix` holds the shared defaults and each
  `service-acme-<domain>.nix` defines one certificate.
- **cho:** Ollama is reachable through its HTTPS proxy on the LAN/VPN only.
  Do not forward its proxy port from the internet; the Ollama API has no
  user-authentication layer.
- **Subfolders:** only group service files into a subfolder when a workload has
  several of them (as `medivh/acme/`). With one service file, keep it directly in the
  workload folder.

## Adding a node or workload

1. Copy `container-1/` to `container-<N>/` and rename the files.
2. Give the node a new MAC address, and set a DHCP reservation for it on the router.
3. Add a node specific `service-<name>-<N>.nix` only if its settings differ.
4. Import the new `host-data.nix` and `container-<N>.nix` in the server's
   [configuration.nix](../computer/server/faml-pc-home_server/configuration.nix).
