#!/usr/bin/env bash
# Sets host-side ownership for the bindMounts declared in:
#   modules/workload/medivh/container-1/container-1.nix
#   modules/workload/heartstone/containers-1/container-1.nix
#
# The workload users (acme, kanidm) only exist inside the containers, not
# on the host, so we chown by numeric uid:gid instead of by name.
# Run as root on the NixOS host.

# uid:gid from modules/users/users/workloads/acme.nix
ACME_ID=2114071989
# uid:gid from modules/users/users/workloads/kanidm.nix
KANIDM_ID=2125606634

set_owner() {
  local path="$1"
  local id="$2"
  if [ ! -d "$path" ]; then
    echo "Creating missing directory: $path"
    mkdir -p "$path"
  fi
  chown -R "${id}:${id}" "$path"
}

# --- modules/workload/medivh/container-1/container-1.nix ---
set_owner "/mnt/ssd/medivh/1/var/lib/acme" "$ACME_ID"
set_owner "/mnt/ssd/medivh/1/var/log/acme" "$ACME_ID"
set_owner "/mnt/ssd/medivh/environments" "$ACME_ID"
set_owner "/mnt/ssd/medivh/secrets" "$ACME_ID"
set_owner "/mnt/ssd/heartstone/1/var/lib/acme/idm.raboes28.nl" "$ACME_ID"
set_owner "/mnt/ssd/heartstone/1/var/lib/kanidm/secrets" "$KANIDM_ID"

# --- modules/workload/heartstone/containers-1/container-1.nix ---
set_owner "/mnt/ssd/heartstone/1/var/lib/kanidm" "$KANIDM_ID"
set_owner "/mnt/zdata/heartstone/1/backups" "$KANIDM_ID"
set_owner "/mnt/ssd/heartstone/var/lib/acme/idm.raboes28.nl" "$ACME_ID"
