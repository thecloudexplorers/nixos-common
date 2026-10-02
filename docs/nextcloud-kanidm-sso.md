# Nextcloud + Kanidm SSO Integration

This document describes the one-time bootstrap needed to let Nextcloud
(`dalaran-1`) authenticate users against Kanidm (`heartstone-1`) via OpenID
Connect, using Nextcloud's `user_oidc` app.

If you're new to this setup, read "How this works" first, and skim
[kanidm-install.md](kanidm-install.md) and
[nextcloud-install.md](nextcloud-install.md) — this document assumes you're
already familiar with both.

## How this works

- The Kanidm side of the integration (the OAuth2 "resource server"/client
  definition, the `nextcloud-users` group, and its scope map) is fully
  declarative, defined in
  [service-kanidm.nix](../modules/workload/heartstone/service-kanidm.nix)
  under `services.kanidm.provision.systems.oauth2.nextcloud`. It's created
  automatically the next time you `nixos-rebuild switch`.
- Kanidm generates a random client secret for this OAuth2 client on its own
  (it's intentionally **not** set declaratively via Nix, since that would
  require a non-default, community-patched Kanidm build — see the comment in
  `service-kanidm.nix`). That secret has to be fetched once via the `kanidm`
  CLI and copied into a host-managed secret file, the same pattern already
  used for Nextcloud's admin password bootstrap.
- On the Nextcloud side, a `nextcloud-oidc-setup.service` (see
  [service-nextcloud.nix](../modules/workload/dalaran/service-nextcloud.nix))
  runs after `nextcloud-setup.service` on every boot and registers/updates the
  `user_oidc` provider (identifier `kanidm`) via `occ user_oidc:provider`,
  reading the client secret from that same host-managed file.
- Only members of the Kanidm `nextcloud-users` group can log in to Nextcloud
  via SSO. Add/remove members in `service-kanidm.nix`.
- This integration only adds SSO as an *additional* login method — existing
  local Nextcloud accounts and password login keep working unless you
  explicitly disable them (see "Optional hardening" below).

## 1. Deploy the declarative Kanidm OAuth2 client

From the host:

```bash
sudo nixos-rebuild switch --flake ~/dev/gh/devjevnl/nixos-config#faml-pc-home_server
```

This creates the `nextcloud` OAuth2 client and `nextcloud-users` group in
Kanidm (inside `heartstone-1`).

## 2. Fetch the generated client secret

This must run **from the host** — `kanidm login` talks to Kanidm's public
HTTPS endpoint and isn't tied to running inside `heartstone-1`:

```bash
kanidm login --name idm_admin
kanidm system oauth2 show-basic-secret nextcloud
```

Copy the printed secret value; you'll need it in the next step.

## 3. Store the client secret for Nextcloud

The `dalaran-1` container reads this secret from a host-managed file (bind-
mounted read-only), the same way it reads the admin password bootstrap file.
Writing the file must also happen **from the host**, since the bind mount is
read-only inside the container:

```bash
sudo sh -c 'printf "%s\n" "PASTE_THE_SECRET_HERE" > /mnt/ssd/dalaran/1/secrets/oidc/nextcloud-client-secret'
sudo chmod 0600 /mnt/ssd/dalaran/1/secrets/oidc/nextcloud-client-secret
sudo chown root:root /mnt/ssd/dalaran/1/secrets/oidc/nextcloud-client-secret
```

Then log into the `dalaran-1` container and restart the setup service from
**inside** it:

```bash
sudo nixos-container root-login dalaran-1
```

Inside the container:

```bash
systemctl restart nextcloud-oidc-setup.service
journalctl -u nextcloud-oidc-setup.service -n 60 --no-pager
```

Expected result: the service exits successfully (`status=0/SUCCESS`) and the
log shows the provider was created/updated.

## 4. Verify

Still inside the `dalaran-1` container (see step 3):

```bash
sudo -u nextcloud nextcloud-occ user_oidc:provider kanidm
```

Then open `https://nextcloud.raboes28.nl/login` in a browser — you should see
a "Login with kanidm" alternative login option in addition to the normal
Nextcloud login form. Log in with a Kanidm account that's a member of the
`nextcloud-users` group.

## 5. Troubleshooting

### No "Login with kanidm" button appears

- Confirm the provider exists: `occ user_oidc:provider` (see step 4). If it's
  missing, check `journalctl -u nextcloud-oidc-setup.service` for errors —
  most commonly a missing/empty client secret file.
- Confirm the `user_oidc` app is enabled: `occ app:list | grep user_oidc`.

### Login fails with "Host ... was not connected to because it violates local access rules"

Only relevant if Kanidm is reachable over a local/private address from
Nextcloud's point of view. `allow_local_remote_servers = true;` is already
set in `service-nextcloud.nix`, so this shouldn't occur with the current
public `idm.raboes28.nl` domain — but if you re-point Kanidm at a
`.internal`/`.local`/private-IP address, re-check that setting.

### "invalid_client" or authentication fails at the Kanidm consent screen

- Re-check the client secret in
  `/mnt/ssd/dalaran/1/secrets/oidc/nextcloud-client-secret` matches the
  current value of `kanidm system oauth2 show-basic-secret nextcloud`
  (secrets are rotated with `kanidm system oauth2 reset-secrets nextcloud`,
  which would invalidate the stored copy).
- Confirm the user is a member of the `nextcloud-users` Kanidm group —
  without any scope map grant, Kanidm denies the whole exchange.

### Redirect URI mismatch error from Kanidm

The `originUrl` in `service-kanidm.nix` must exactly match Nextcloud's
`user_oidc` callback: `https://nextcloud.raboes28.nl/apps/user_oidc/code`.
If you rename the Nextcloud host, update `originUrl` in `service-kanidm.nix`
too, then redeploy.

## Optional hardening

These are **not** applied by default, since they can lock out local/admin
accounts if something goes wrong with SSO. Apply manually once you've
confirmed SSO login works end-to-end.

- Make Kanidm the only login method (still overridable via
  `?direct=1` on the login page for local/admin accounts):
  ```bash
  sudo nixos-container run dalaran-1 -- sudo -u nextcloud nextcloud-occ config:app:set --value=0 user_oidc allow_multiple_user_backends
  ```
- Disable the "lost password" link and email changes (already set in
  `service-nextcloud.nix`'s `settings`).

## Glossary

- **`user_oidc`**: the Nextcloud app (already pinned in `extraApps` in
  `service-nextcloud.nix`) that adds OpenID Connect login as a user backend.
- **OAuth2 resource server / client**: Kanidm's term for an application
  registered to authenticate via OAuth2/OIDC — here, Nextcloud.
- **scope map**: a Kanidm mapping from group membership to OAuth2 scopes
  granted to that group's members for a given client; required for anyone to
  be allowed through the OIDC exchange at all.
- **`occ`**: Nextcloud's command-line admin tool; `nextcloud-occ` on the host
  is a wrapper generated by the NixOS module that runs it as the correct user
  inside `dalaran-1`.
