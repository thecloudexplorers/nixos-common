---
name: add-workload-secret
description: Give a workload container a secret (password, token, client secret) in this NixOS repo without putting it in the Nix store. Use when a service needs passwordFile, credentialsFile, adminpassFile, client secrets or any sensitive value.
---

# Add a secret to a workload

Secrets never go into Nix files: everything in them ends up world-readable in `/nix/store`. Use a file outside the store, bind mounted into the container. Reference: `modules/workload/dalaran/` (admin and oidc secrets).

## Steps

1. **Host directory** in `host-data.nix`, with a comment saying what it holds:
   ```nix
   "d /mnt/ssd/${workloadName}/${toString workloadNode}/secrets/<name> 0700 root root -"
   "z /mnt/ssd/${workloadName}/${toString workloadNode}/secrets/<name> 0700 root root -"
   ```
2. **Bind mount** in `container-<N>/container-<N>.nix`, read-only:
   ```nix
   "/${workloadName}-secrets-<name>-${workloadService}" = {
     hostPath = "/mnt/ssd/${workloadName}/${toString workloadNode}/secrets/<name>";
     mountPoint = "/tmp/${workloadName}-<name>";
     isReadOnly = true;
   };
   ```
3. **Service option** in `service-<service>.nix`, pointing at a path string, never the contents:
   ```nix
   secretFile = "/tmp/${workloadName}-<name>/<service>-<file-name>";
   ```
   Use the real option of the service (`adminpassFile`, `passwordFile`, `credentialsFile`, ...). Verify its name for nixpkgs 26.05 on search.nixos.org; do not guess.
4. **Document how the user fills it in** in the workload `README.md` or in `docs/` (file name, permissions, how to generate it, for example `openssl rand -base64 32`).

## Never

- Write or generate the secret value yourself, or put it in any tracked file.
- Use `builtins.readFile` on a secret, or options that take the secret as a plain string.
- Loosen the `0700 root root` mode.

If the service only supports a plain-string option, say so and ask the user how to proceed instead of working around it.

Then follow the `verify-nix-change` skill.
