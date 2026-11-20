# Federated Nextcloud Talk — Design & Deployment Guide (HPB + NATS + TURN)

This document is the design for a **turn-key, NixOS-declared Nextcloud Talk
deployment with full federation support**: text chat, audio, and video calls
within one instance *and* between independent instances. It is written for
any audience — from a single small deployment to a federation of many
instances ("start small, scale big"): every layer below can be adopted
independently, and each one adds capability without reworking the others.

Per instance, the stack is:

``` plaintext
Talk clients ──wss://talk.<domain>:3478──▶ HPB (nextcloud-spreed-signaling)
                                                │ backend API (shared secret)
                                                ▼
                                          Nextcloud (Talk/spreed)
                                                │
                                    ┌─────────┴──────────┐
                                    ▼                    ▼
                              NATS (loopback bus)   coturn (STUN/TURN) on turn.<domain>
                                                       ▲ :3478/:5349 + relay range
WebRTC media (P2P if possible, else TURN relay) ───────┘
```

To explain connectivity and federation, this document uses two placeholder
instances: **instance A** (`nextcloud.<domain-a>`, HPB `talk.<domain-a>`,
TURN `turn.<domain-a>`) and **instance B** (same shape under `<domain-b>`).
Any number of instances can federate; A and B are just the smallest useful
example.

Federated calls additionally flow: HPB-A ──wss──▶ HPB-B (authenticated with
the federation shared secret), and Nextcloud-A ──HTTPS 443──▶ Nextcloud-B
(OCS federation API).

---

## 0. How to use this document

Everything is parameterized by *instance parameters* (Appendix A). Substitute
your own values for the `<...>` placeholders. The Nix snippets are plain NixOS
configuration and can be dropped into any flake or `nixosSystem` as-is; this
repository additionally ships ready-made modules for this stack under the
`tce.modules.*` namespace (see the repo README for the
contract pattern), so consumers only provide the parameters.

**Modules.** Section 4 defines modules M0–M6. Each module is one Nix module
file (plus its container/networking wiring) with a clearly declared interface
(URLs, ports, secret names). Any module can be implemented, built, and tested
independently; Section 5 gives the integration order. Teams can split the
modules across contributors — they share no code and no runtime dependency
until the wiring step.

Validate a configuration read-only with
`nix build .#nixosConfigurations.<host>.config.system.build.toplevel` or
`nix flake check`.

---

## 1. Goals and scope

**In scope**:

- Federated Talk **chat** (works over plain HTTPS federation) and federated
  **audio/video calls** (1:1 and group) between instances.
- Local calls within each instance.
- Everything declared in NixOS (modules, agenix secrets, firewall, ACME); the
  only imperative step is the one-time federation pairing (Section 4, M5).

**Out of scope / non-goals**:

- Recording backend, Janus MCU, SIP bridge — the HPB runs in signaling-only
  mode (`mcu.type = null`).
- Any specific hosting location: this design works on a single server, in a
  homelab, at a site, or on a VPS. Section 3 covers the connectivity options.

---

## 2. Architecture

Three functional layers per instance:

| Layer | Component | Role |
| ----- | --------- | ---- |
| Application | Nextcloud core + Talk (`spreed`) | UI, auth, room/user logic, OCS federation API. Talks to the HPB through the backend API using a shared secret. |
| Signaling (control plane) | `nextcloud-spreed-signaling` (HPB) on `talk.<domain>:3478` (WSS) | Replaces PHP-based signaling. Manages session/room lifecycle, exchanges SDP and ICE candidates. **Required for federated calls** — see Section 9. |
| Signaling bus | NATS on loopback | Message bus inside the HPB (and between HPB nodes if clustered later). Never exposed. |
| Media traversal (data plane) | coturn on `turn.<domain>` | STUN (discovery) on 3478 UDP/TCP; TURN relay on 3478 + 5349 (TLS/DTLS) + a narrow UDP relay range. Credentials minted via the TURN REST API by the HPB. |

Why each piece exists:

| Component | Problem solved | Impact of absence |
| --------- | -------------- | ----------------- |
| HPB | Cross-instance call coordination; calls with more than ~4 participants | Federated calls black-screen; calls stay local-only |
| NATS | HPB internal messaging; future clustering | HPB can fall back to `nats://loopback`, but then no clustering and no external publishers |
| STUN | Clients discover their public IP/port | No P2P candidates behind NAT |
| TURN | Relay when P2P fails (strict firewalls, symmetric NAT) | Calls "connect" but never carry media |

Traffic between two instances (and only this traffic crosses the sites):

``` plaintext
A: Nextcloud ──HTTPS 443──▶ B: Nextcloud     (OCS federation: trust, rooms, signaling/settings)
A: HPB       ──WSS 3478──▶ B: HPB           (federated signaling, shared-secret auth)
A: clients   ──WSS 3478──▶ A: talk.<domain-a> (each side's clients connect to their OWN HPB;
B: clients   ──WSS 3478──▶ B: talk.<domain-b>  the two HPBs then federate the room)
A: HPB       ──HTTPS──▶ A: turn.<domain-a>  (TURN REST API: the HPB mints credentials for its
                                             own clients from its own coturn; stays local)
A: clients   ◀──WebRTC──▶ B: clients        (P2P media if possible, else via TURN relay:
                                             A: clients ──▶ A: turn.<domain-a> ──▶ B: clients)
```

NATS never leaves the signaling host/container.

---

## 3. Connectivity and exposure model

The design supports anything from a **least-permissive private setup** to a
**fully public** one. Pick per instance; the port table in 3.3 is the
complete set of ports the stack uses either way.

### 3.1 Deployment topologies

| Topology | DNS | Edge routing | Exposure |
| -------- | --- | ------------ | -------- |
| **Least permissive (recommended to start)** | Names resolve only internally (split-horizon/local DNS), AAAA-only if IPv6 is used; no public A/AAAA | IPv6: no NAT/port-forwarding needed — only inbound firewall allow rules (optionally restricted to the peer's prefix). IPv4-only: not possible without NAT | Not discoverable via public DNS; only allowlisted peers can reach the service ports |
| **Private with public names** | Public A/AAAA (or A-only) records | IPv6: inbound firewall rules. IPv4: NAT/port-forwarding (DNAT) on the edge router to the internal endpoint | Reachable by anyone who resolves the name |
| **Public / "scale big"** | Public records | Same as above, open to the internet on the ports in 3.3 | Fully public service (standard HPB deployment) |

IPv4/IPv6 guidance:

- **IPv6-only is the least permissive setup**: with global IPv6 addresses there
  is no NAT, so no port-forwarding is required — the edge firewall only needs
  inbound allow rules on the ports in 3.3 (optionally scoped to specific peer
  prefixes). Publishing only AAAA records (no A records) keeps the service off
  the IPv4 internet entirely.
- **IPv4 requires NAT/port-forwarding**: the edge router must DNAT the public
  IPv4 + port to the internal endpoint for every port in 3.3 (443, 3478, 5349,
  and the UDP relay range). Expect more unsolicited traffic on IPv4.
- **Dual-stack**: publish both A and AAAA and configure both rule sets.

### 3.2 DNS

- Each instance needs names for `nextcloud.<domain>`, `talk.<domain>`,
  `turn.<domain>`. Where they resolve (public zone vs. local/split-horizon
  DNS) is your choice per 3.1.
- Each instance must also be able to resolve the **peer's** hostnames
  (`nextcloud./talk./turn.` of the other domain) to the peer's endpoints —
  via public DNS, or via local DNS / `extraHosts` entries in the containers.

### 3.3 Connectivity requirements (edge router / firewall port table)

Whatever the topology, these are the only ports the stack needs. On the edge
device, allow (or DNAT, for IPv4) exactly these:

| # | Destination endpoint | Port | Protocol | Purpose |
| - | -------------------- | ---- | -------- | ------- |
| 1 | `nextcloud.<domain>` (host or reverse proxy on 443) | 443 | TCP | HTTPS federation (OCS API, signaling/settings) |
| 2 | `talk.<domain>` (HPB) | 3478 | TCP | WSS signaling (clients + peer HPB) |
| 3 | `turn.<domain>` (coturn) | 3478 | UDP + TCP | STUN binding, TURN allocate/refresh |
| 4 | `turn.<domain>` | 5349 | TCP + UDP | TURN over TLS/DTLS (`turns:`) |
| 5 | `turn.<domain>` | 49152–49252 | UDP | TURN relay range (narrowed on purpose, see M3) |

Notes:

- Return traffic for outbound flows is stateful and needs no rule.
- NATS (4222) is **never** exposed — it binds loopback inside the signaling
  host and has no firewall entry.
- In the least-permissive topology, scope rules 1–5 to the peer's IP
  prefix/addresses instead of opening them to the world.

### 3.4 TLS certificates (ACME)

- If the names resolve publicly, HTTP-01 works. If they don't (split-horizon
  setup), use **DNS-01**: only `_acme-challenge.*` TXT records are published in
  the public zone, which does not reveal any A/AAAA or endpoints. Configure
  your DNS provider in the ACME module (e.g. lego's `dnsProvider`).
- Certs are consumed from the ACME directory
  (`/var/lib/acme/<host>/cert.pem` + `key.pem`; in the NixOS ACME module
  `cert.pem` is a symlink to `fullchain.pem`, i.e. the full chain — suitable
  for the Go HPB and coturn alike). When running services in containers, stage
  the cert directory on the host and bind-mount it read-only into the container.

### 3.5 P2P vs relay for media

With strict inbound rules (only the table in 3.3), cross-site WebRTC media
cannot open new inbound flows on ephemeral ports, so **cross-site calls use
the TURN relay by default** — deterministic and usually low-latency enough.
Calls within one site can still go P2P. Optional relaxation, off by default:
allow the peer prefix on the UDP ephemeral range (e.g. 32768–60999) to enable
direct P2P media between sites. Do not open more than that.

### 3.6 Host/container firewall (NixOS)

Each host or container declares only its own ports in `networking.firewall`:

- signaling host/container: TCP 3478 only.
- TURN host/container: TCP+UDP 3478, 5349, and UDP range 49152–49252
  (`allowedUDPPortRanges`).
- Nextcloud host/container: TCP 443 only (do not open 3478 here — it belongs
  to the signaling/TURN hosts).

---

## 4. Modules

Each module = one Nix module file + container/networking wiring + secrets. The
"Provides" column is the interface other modules consume. Modules are
independently implementable and testable; Section 5 gives the integration
order.

| ID | Module | Provides | Depends on |
| -- | ------ | -------- | ---------- |
| M0 | Edge: DNS + ACME + edge allowlist | names, certs, reachability per instance | — |
| M1 | NATS bus | `nats://127.0.0.1:4222` (loopback, signaling host) | M0 |
| M2 | HPB signaling server | `wss://talk.<domain>:3478/spreed` | M0, M1 |
| M3 | TURN/STUN relay (coturn) | `turn/turns/stun: turn.<domain>` on 3478/5349 + relay range | M0 |
| M4 | Nextcloud Talk wiring | spreed → HPB registration, STUN config | M2 |
| M5 | Federation pairing | trusted servers (status=1) + HPB peer backends on both instances | M2+M4 on A and B |
| M6 | Verification | end-to-end test results | all |

### M0 — Edge: DNS + ACME + edge allowlist (per instance)

- DNS records per 3.2; peer hostnames resolvable per 3.2.
- ACME certs for `talk.<domain>` and `turn.<domain>` per 3.4, staged to a
  host directory and bind-mounted read-only into the respective containers at
  `/var/lib/acme/<host>/` (or consumed directly via `security.acme` when not
  using containers).
- Edge rules per the table in 3.3.
- **Acceptance:** from the peer network (or the internet, for public
  topologies), `curl https://talk.<domain>:3478/api/v1/welcome` returns JSON
  with a `version` field (once M2 is up).

### M1 — NATS message bus

Runs on the signaling host, bound to loopback. A real NATS server (not the
HPB's built-in `nats://loopback`) is the module boundary that allows
clustering the HPB later and attaching external publishers, without changing
the HPB config interface.

```nix
{
  services.nats = {
    enable = true;
    serverName = "<signaling-host>";
    port = 4222;
    jetstream = false; # core NATS only; enable if clustering needs persistence
    settings = {
      # `listen` takes precedence over `port` -> loopback only.
      # The module validates the config at build time (validateConfig = true).
      listen = "127.0.0.1:4222";
    };
  };
  # Deliberately NO networking.firewall entry for 4222:
  # NATS must stay unreachable from outside this host.
}
```

- **Provides:** `nats://127.0.0.1:4222` (host-local).
- **Acceptance:** at runtime `ss -ltn` shows 4222 on 127.0.0.1 only; from
  another host, connecting to `<host-ip>:4222` fails (firewall).

### M2 — HPB signaling server

`services.nextcloud-spreed-signaling` (nixpkgs) on the signaling host, TLS
terminated directly on 3478 (no reverse proxy needed on this host; the edge
allowlists 3478 TCP to it).

```nix
let
  domain = "<domain>";                              # instance parameter
  talkHost = "talk.${domain}";
  turnHost = "turn.${domain}";
  localNextcloudUrl = "https://nextcloud.${domain}";
  peerNextcloudUrl = "https://nextcloud.<peer-domain>";  # instance B (parameter)
in
{
  age.secrets."hpb-backend-secret".file = ./secrets/hpb-backend-secret.age;
  age.secrets."hpb-federation-secret".file = ./secrets/hpb-federation-secret.age;
  age.secrets."hpb-internalsecret".file = ./secrets/hpb-internalsecret.age;
  age.secrets."hpb-session-hashkey".file = ./secrets/hpb-session-hashkey.age;
  age.secrets."hpb-session-blockkey".file = ./secrets/hpb-session-blockkey.age;
  age.secrets."turn-secret".file = ./secrets/turn-secret.age;

  services.nextcloud-spreed-signaling = {
    enable = true;
    # TLS directly on 3478; cert from ACME (M0).
    # configureNginx stays false — no reverse proxy on this host.
    settings = {
      https = {
        listen = "[::]:3478";
        certificate = "/var/lib/acme/${talkHost}/cert.pem";
        key = "/var/lib/acme/${talkHost}/key.pem";
      };
      nats.url = [ "nats://127.0.0.1:4222" ];   # M1 interface
      clients.internalsecretFile = config.age.secrets."hpb-internalsecret".path;
      sessions.hashkeyFile = config.age.secrets."hpb-session-hashkey".path;
      sessions.blockkeyFile = config.age.secrets."hpb-session-blockkey".path;
      # TURN handed to clients by the HPB; credentials minted via the
      # coturn REST API using the shared secret (M3).
      turn = {
        servers = [
          "turn:${turnHost}:3478?transport=udp"
          "turn:${turnHost}:3478?transport=tcp"
          "turns:${turnHost}:5349?transport=tcp"
        ];
        secretFile = config.age.secrets."turn-secret".path;
      };
    };
    backends = {
      # local Nextcloud; secret == the one given to `occ talk:signaling:add` (M4)
      local = {
        urls = [ localNextcloudUrl ];
        secretFile = config.age.secrets."hpb-backend-secret".path;
      };
      # federation: remote Nextcloud; secret == oc_trusted_servers.shared_secret
      # for the peer (set once, same value on both sides — see M5)
      peer = {
        urls = [ peerNextcloudUrl ];
        secretFile = config.age.secrets."hpb-federation-secret".path;
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 3478 ];
}
```

Notes:

- The module substitutes `*File` secrets into the generated `server.conf` at
  service start, so no plaintext secret lands in the Nix store.
- The `[federation]` section (timeouts, `skipverify`) is left at upstream
  defaults; with publicly trusted certs `skipverify` stays false.
- **Provides:** `wss://talk.<domain>:3478/spreed` for clients; backend API for
  the local Nextcloud; federation target for the peer HPB.
- **Acceptance:** `curl -i https://talk.<domain>:3478/api/v1/welcome` → 200
  JSON with `version`; the service is clean in systemd; after M4,
  `occ talk:signaling:list` shows the HPB and the admin UI shows it green.

### M3 — TURN/STUN relay (coturn)

`services.coturn` (nixpkgs) on its own host/container (`turn.<domain>`). The
nixpkgs coturn module does **not** open any firewall ports — declare them
explicitly. The relay range is narrowed to 49152–49252 so the edge allowlist
stays small.

```nix
let
  domain = "<domain>";
  turnHost = "turn.${domain}";
in
{
  age.secrets."turn-secret".file = ./secrets/turn-secret.age;

  services.coturn = {
    enable = true;
    listening-port = 3478;      # STUN + TURN, UDP and TCP
    tls-listening-port = 5349;  # TURN over TLS/DTLS ("turns:")
    min-port = 49152;
    max-port = 49252;           # narrow relay range; matches the edge allowlist
    lt-cred-mech = true;
    use-auth-secret = true;     # TURN REST API; the HPB mints credentials
    static-auth-secret-file = config.age.secrets."turn-secret".path;
    realm = turnHost;
    cert = "/var/lib/acme/${turnHost}/cert.pem";
    pkey = "/var/lib/acme/${turnHost}/key.pem";
    no-cli = true;
  };

  networking.firewall.allowedTCPPorts = [ 3478 5349 ];
  networking.firewall.allowedUDPPorts = [ 3478 5349 ];
  networking.firewall.allowedUDPPortRanges = [
    { from = 49152; to = 49252; }
  ];
}
```

- The `static-auth-secret` must equal the HPB's `turn.secretFile` value (the
  same secret consumed on both hosts).
- **Provides:** `stun:${turnHost}:3478`,
  `turn:${turnHost}:3478?transport=udp|tcp`, `turns:${turnHost}:5349?transport=tcp`,
  relay on UDP 49152–49252.
- **Acceptance:** from the peer network, a TLS handshake against
  `turn.<domain>:5349` and a STUN binding request against UDP 3478 succeed
  (`turnutils_stunclient turn.<domain>` returns a XOR-MAPPED-ADDRESS); coturn
  logs show allocations when a call relays.

### M4 — Nextcloud Talk wiring

On the Nextcloud host, extend the existing Nextcloud setup oneshot (the one
that wires app config via `occ`) — or add it to your `services.nextcloud`
module:

```nix
# inside the systemd oneshot script, after nextcloud-setup:
#   occ talk:signaling:add --verify "https://talk.<domain>:3478" "$(cat <hpb-backend-secret-file>)"
#   occ talk:stun:add "turn.<domain>:3478"
```

Also make sure the Nextcloud host can resolve `talk.<domain>` (and the peer's
`nextcloud./talk./turn.` hostnames) without hairpinning through the public IP —
e.g. `networking.extraHosts` entries pointing at the internal addresses.

- **Depends on:** M2 (HPB up, cert present), M0.
- **Acceptance:** `occ talk:signaling:list` shows `https://talk.<domain>:3478`;
  `occ config:app:get spreed signaling_servers` is non-empty; admin UI → Talk
  shows the signaling server connected (green); a **local** 1:1 call between
  two users of the same instance works with media.

### M5 — Federation pairing (both instances)

1. On both Nextclouds, add the peer as a trusted server (admin UI → Sharing →
   Federated cloud, or via the first federated chat). Ensure
   `overwrite.cli.url` / `overwritehost` / `overwriteprotocol` /
   `allow_local_remote_servers` are set in `services.nextcloud.settings` —
   the NixOS Nextcloud module does **not** derive `overwrite.cli.url` from
   `hostName`, and without it CLI-generated URLs degrade to
   `http://localhost/`, which breaks the shared-secret exchange (Section 9).
2. Because the automatic `RequestSharedSecret` exchange is flaky across
   versions (Section 9.1), set the shared secret **manually and identically
   on both sides**:

   ```sql
   UPDATE oc_trusted_servers
   SET shared_secret = '<same-random-string-on-both-sides>', status = 1
   WHERE url = 'https://nextcloud.<peer-domain>';
   ```

3. Store that same string as the agenix secret `hpb-federation-secret.age` on
   **both** instances — it is the `backends.peer.secret` of each HPB (M2).
   This makes the pairing declarative from then on.
4. Verify: `oc_trusted_servers.status = 1` with non-empty `shared_secret` on
   both sides; federated **chat** works.

### M6 — Verification (end-to-end)

Full checklist in Section 8. Short version: local call → federated chat →
federated 1:1 call (watch for the `helloAuthParams` warning disappearing from
the Nextcloud log) → group call → forced-relay test (block direct P2P,
confirm media flows via TURN and coturn logs allocations).

---

## 5. Build and integration order

Modules combine in this order; each step is independently testable, and
contributors can work in parallel and merge at the checkpoints:

1. **M0** on both instances (DNS, ACME entries, edge allowlist). Nothing else
   works without names + certs + reachability.
2. **M1** (NATS) — builds and runs standalone on the signaling host.
3. **M2** (HPB) on top of M1. Checkpoint: the `welcome` endpoint answers on
   3478 from the peer network.
4. **M4** (Nextcloud wiring) on each instance. Checkpoint: local 1:1 call with
   media.
5. **M3** (coturn) — standalone on the TURN host. Checkpoint: STUN binding +
   TLS handshake from the peer network.
6. **Wire M2→M3**: HPB `turn.servers` + `turn.secretFile` (already in the M2
   sketch) — restart the HPB. Checkpoint: clients receive TURN credentials in
   the HPB hello; a forced-relay call works.
7. **M5** (federation pairing) — both sides, exchanging peer parameters
   (hostnames, endpoints, shared secret). Checkpoint: trusted servers green,
   HPB peer backends configured on both sides.
8. **M6**: federated 1:1 and group calls A↔B; verify no `helloAuthParams`
   warnings, both HPBs log sessions, media flows (P2P or relay).

Parallel-work note: M1/M2 and M3 share no code and no runtime dependency until
step 6, so they can be implemented and brought online independently and then
combined.

---

## 6. Reference implementation layout

A generic flake layout for one instance (repeat per instance; containers are
optional — the same services run fine directly on a host):

``` plaintext
modules/
├── nextcloud.nix            # services.nextcloud + occ oneshot (M4)
├── talk-signaling.nix       # M1 + M2 (NATS + HPB)
├── talk-turn.nix            # M3 (coturn)
├── acme.nix                 # M0: certs for talk.<domain> / turn.<domain>
└── containers/              # optional: run signaling/turn as NixOS containers
    ├── signaling.nix        #   container with privateNetwork, bind-mounted
    │                        #   ACME dir + state dir, firewall TCP 3478
    └── turn.nix             #   container with firewall 3478/5349 + UDP relay range
secrets/                     # agenix-encrypted (Section 7)
```

Container notes (when used): `privateNetwork = true` with a host bridge,
DHCP primary plus static IP fallback, pinned MAC, `extraHosts` for the local
service names and the peer's hostnames, and bind-mounts for the ACME cert
directory (read-only) and service state. A container imports only the service
modules it needs, not the whole workload aggregate.

---

## 7. Secrets inventory (agenix)

All secrets are age-encrypted files; only ciphertext is committed. Generate
with `openssl rand -hex 32` (hashkey: 32 or 64 bytes hex; blockkey: 16/24/32
bytes hex).

| Secret file | Consumed by | Purpose |
| ----------- | ----------- | ------- |
| `hpb-backend-secret.age` | HPB `backends.local.secretFile`; Nextcloud occ oneshot | HPB ↔ local Nextcloud (`occ talk:signaling:add`) |
| `hpb-federation-secret.age` | HPB `backends.peer.secretFile` (both instances) | HPB ↔ peer Nextcloud/HPB; equals `oc_trusted_servers.shared_secret` |
| `hpb-internalsecret.age` | HPB `clients.internalsecretFile` | internal clients of the HPB |
| `hpb-session-hashkey.age` | HPB `sessions.hashkeyFile` | session checksums |
| `hpb-session-blockkey.age` | HPB `sessions.blockkeyFile` | session encryption |
| `turn-secret.age` | HPB `turn.secretFile` + coturn `static-auth-secret-file` | TURN REST API shared secret (same value on both hosts) |

---

## 8. End-to-end verification checklist

Run on both instances; cross-checks marked (A↔B).

1. **Trust:** the `oc_trusted_servers` row for the peer has `shared_secret`
   set and `status = 1` (green in the admin UI). (A↔B)
2. **HPB:** `occ talk:signaling:list` shows `https://talk.<domain>:3478`;
   `curl -i https://talk.<domain>:3478/api/v1/welcome` → 200 JSON `version`
   (from the peer network too). (A↔B)
3. **Federation API:** from A,
   `curl -X POST https://nextcloud.<domain-b>/ocs/v2.php/apps/federation/api/v1/request-shared-secret ...`
   returns 200 (Section 9.1, step 6). (A↔B)
4. **Signaling settings:** during a federated call, A's log shows
   `GET /ocs/v2.php/apps/spreed/api/v3/signaling/settings` on B **without**
   the `Undefined array key "helloAuthParams"` warning. (A↔B)
5. **Local call:** 1:1 call between two local users, audio+video. (each)
6. **Federated call:** 1:1 call A-user ↔ B-user; both HPBs log sessions;
   media flows. Then a group call with users from both instances. (A↔B)
7. **Relay test:** block direct P2P (or rely on the strict-firewall default)
   and confirm the call still carries media via TURN: coturn logs
   allocations, browser ICE shows a `relay` candidate on `turn.<domain>`.
8. **NATS isolation:** from another host, port 4222 on the signaling host is
   unreachable; on the host itself it is 127.0.0.1 only.
9. **Exposure audit:** edge rules match the table in 3.3 exactly; in the
   least-permissive topology, no public A records exist for the hostnames and
   no IPv4 listeners are open on 3478/5349.

---

## 9. Troubleshooting (federation & Talk)

Use `SERVER_A` / `SERVER_B` for the two instances. All commands assume shell
access to the Nextcloud host and `occ` on PATH.

### 9.1 Federation trust: trusted servers and the shared secret

When server A adds server B as a trusted server, A inserts a row into
`oc_trusted_servers` with a random 16-char `token` and queues a background
job `OCA\Federation\BackgroundJob\RequestSharedSecret`, which POSTs to the
remote:

``` plaintext
POST <remote>/ocs/v2.php/apps/federation/api/v1/request-shared-secret
body: url=<absolute URL of the local server>&token=<local token>&format=json
```

The server with the higher token initiates the exchange; both sides end up
with the same `shared_secret`. `status` values: `1` = paired (green), `2` =
pending (yellow), `3` = failure, `4` = revoked. A job that keeps failing
disappears after ~6 attempts and after a 30-day lifespan (setting `status=3`)
— the failing job is the signal to look at.

Diagnosis on **both** servers:

```bash
# 1. Trusted server rows
psql -d nextcloud -c 'select id, url, token, shared_secret, status from oc_trusted_servers;'

# 2. Pending federation jobs
occ background-job:list --class 'OCA\Federation\BackgroundJob\RequestSharedSecret'
occ background-job:list --class 'OCA\Federation\BackgroundJob\GetSharedSecret'

# 3. The URL the CLI sends (empty -> falls back to http://localhost/...,
#    a classic cause of the remote rejecting the request)
occ config:system:get overwrite.cli.url
occ config:system:get overwritehost
occ config:system:get overwriteprotocol
occ config:system:get allow_local_remote_servers

# 4. Why the job failed (one info line per attempt)
grep -Ei 'shared secret|Could not connect|responded with|refused to ask' \
  /var/lib/nextcloud/data/nextcloud.log | tail -50

# 5. Compare tokens on both sides; the server whose token for the other is
#    LARGER must be the one whose RequestSharedSecret job succeeds.

# 6. Replay the job's request manually to see the remote's answer:
curl -sS -o /dev/null -w '%{http_code}\n' -X POST \
  'https://SERVER_B/ocs/v2.php/apps/federation/api/v1/request-shared-secret' \
  --data-urlencode 'url=https://SERVER_A' \
  --data-urlencode 'token=<token-from-A-for-B>' \
  --data-urlencode 'format=json'

# 7. Reachability both ways (federation needs A->B AND B->A):
curl -sS https://SERVER_B/status.php
curl -sS https://SERVER_A/status.php   # from B
```

Common root causes:

1. **`overwrite.cli.url` not set** — set it explicitly in
   `services.nextcloud.settings`:

   ```nix
   settings = {
     overwritehost = "nextcloud.<domain>";
     overwriteprotocol = "https";
     "overwrite.cli.url" = "https://nextcloud.<domain>";
     allow_local_remote_servers = true;
   };
   ```

   Then re-create the pairing so a fresh job runs with the correct URL.
2. **Token deadlock on Nextcloud ≤ 31** — fixed upstream in Nextcloud 32
   (server PR #54372); upgrade if needed.
3. **Bruteforce protection** — repeated 403s can escalate to 429 on the
   remote; wait or temporarily disable `auth.bruteforce.protection.enabled`
   while repairing.
4. **Re-create the pairing** to regenerate a fresh token + job: remove the
   peer from the trusted-servers list on both sides and re-add it, then run
   `occ background-job:execute <id>` until no job remains.
5. **Manual workaround** (last resort): set the same random `shared_secret`
   on both sides and mark the row OK (the SQL in M5 step 2). Prefer fixing the
   exchange; use this to make the pairing declarative afterwards.

### 9.2 Talk federated calls: the HPB

- Federated **chat** uses plain HTTPS federation (port 443) — no WebRTC.
- **Calls** need WebRTC signaling. Without an external signaling server,
  Talk runs in `internal` mode, which only works for participants on the SAME
  server. For a federated room, the local Talk app asks the REMOTE server for
  its signaling settings (`GET <remote>/ocs/v2.php/apps/spreed/api/v3/signaling/settings`)
  and expects an HPB endpoint plus `helloAuthParams`. If the remote has no
  HPB, the local server logs:

  ``` plaintext
  Undefined array key "helloAuthParams" at .../spreed-*/lib/Controller/SignalingController.php
  ```

  and the call UI opens but media/signaling never establish → **black screen**.
  Conclusion: **federated calls require an HPB on BOTH instances.**

- HPB checklist (both instances): signaling server with TLS on TCP 3478;
  reachable per 3.3; `curl -i https://talk.<domain>:3478/api/v1/welcome`
  returns JSON with `version`; `backends` includes the local Nextcloud URL
  (and the peer's, for federation) with the shared secret; registered in Talk
  via `occ talk:signaling:add --verify https://talk.<domain>:3478 '<secret>'`;
  STUN/TURN per M3.
- If signaling connects but there is still no audio/video: check STUN/TURN
  (ICE candidates in the browser console), and confirm UDP 3478 + the relay
  range are allowed per 3.3.

### 9.3 References for troubleshooting

- Nextcloud server issues: [#39941](https://github.com/nextcloud/server/issues/39941)
  (pairing-flow analysis), [#54372](https://github.com/nextcloud/server/pull/54372)
  (NC 32 deadlock fix)
- Source: `apps/federation/lib/BackgroundJob/RequestSharedSecret.php`,
  `apps/federation/lib/TrustedServers.php`,
  `spreed/lib/Controller/SignalingController.php` in nextcloud/server & spreed

---

## 10. References

- Nextcloud Talk HPB docs: <https://nextcloud-talk.readthedocs.io/en/latest/HPB/>
  and quick install: <https://nextcloud-talk.readthedocs.io/en/latest/quick-install/>
- Signaling server config reference (upstream `server.conf.in`, incl. the
  `[federation]` and `[turn]` sections):
  <https://github.com/strukturag/nextcloud-spreed-signaling>
- Talk app source: `spreed/lib/Controller/SignalingController.php`
  (`getFederationSettings`), `spreed/lib/Config.php` (`getSignalingMode`).
- NixOS modules (nixpkgs):
  `nixos/modules/services/networking/nextcloud-spreed-signaling.nix` (options:
  `backends.<name>.urls/secretFile`, `settings.https.*`, `settings.nats.url`,
  `settings.clients.internalsecretFile`, `settings.sessions.*File`,
  `settings.turn.servers/secretFile/apikeyFile`),
  `nixos/modules/services/networking/nats.nix` (`services.nats.*`),
  `nixos/modules/services/networking/coturn.nix` (`services.coturn.*`; note: it
  does not open firewall ports itself).
- Federation admin docs:
  <https://docs.nextcloud.com/server/stable/admin_manual/configuration_files/federated_cloud_sharing_configuration.html>

---

## Appendix A — Instance parameters

Fill in per instance when adopting this design. A and B are the two federating
instances used throughout this document.

| Parameter | Instance A | Instance B |
| --------- | ---------- | ---------- |
| `domain` | `<domain-a>` | `<domain-b>` |
| Nextcloud host | `nextcloud.<domain-a>` | `nextcloud.<domain-b>` |
| HPB host | `talk.<domain-a>` | `talk.<domain-b>` |
| TURN host | `turn.<domain-a>` | `turn.<domain-b>` |
| Nextcloud host/container | `<host-a>` | `<host-b>` |
| Signaling host/container | `<host-a>` (or dedicated) | `<host-b>` (or dedicated) |
| TURN host/container | `<host-a>` (or dedicated) | `<host-b>` (or dedicated) |
| Internal IPs (v4/v6) | `<...>` | `<...>` |
| Public IPs (v4/v6) | `<...>` | `<...>` |
| ACME | `<DNS-01 provider>` | `<DNS-01 provider>` |
| Peer prefix/addresses to allowlist | B's addresses | A's addresses |
| Edge ports allowed (both sides) | 443 TCP; 3478 TCP (talk); 3478+5349 TCP/UDP and 49152–49252 UDP (turn) — scoped per 3.1/3.3 | same, mirrored |
