#!/usr/bin/env bash
# Creates and chowns the bindMounts hostPath directories declared in the
# given container-1.nix files. Paths are resolved dynamically from each
# file's `let` bindings, so no paths need to be hardcoded here.
#
# Usage: sudo bash scripts/set-bindmount-permissions.sh <container.nix> [container.nix ...]
#
# Example:
#   sudo bash scripts/set-bindmount-permissions.sh \
#     modules/workload/medivh/container-1/container-1.nix \
#     modules/workload/heartstone/containers-1/container-1.nix
#
# The workload users (acme, kanidm) only exist inside the containers, not
# on the host, so we chown by numeric uid:gid instead of by name.

set -euo pipefail

# uid:gid from modules/users/users/workloads/acme.nix
ACME_ID=966
# uid:gid from modules/users/users/workloads/kanidm.nix
KANIDM_ID=960

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 <container.nix> [container.nix ...]" >&2
  exit 1
fi

# Resolves ${name} / ${toString name} references in a nix string using the
# name -> value bindings captured from that file's `let` block. Repeats
# until stable so nesting (e.g. a let-bound var that itself references
# another let-bound var) resolves regardless of associative array order.
resolve_nix_string() {
  local value="$1"
  local -n vars_ref="$2"
  local name previous
  while [[ "$value" == *'${'* ]]; do
    previous="$value"
    for name in "${!vars_ref[@]}"; do
      value="${value//\$\{toString $name\}/${vars_ref[$name]}}"
      value="${value//\$\{$name\}/${vars_ref[$name]}}"
    done
    # No substitution changed anything this pass, stop to avoid looping forever
    [ "$value" == "$previous" ] && break
  done
  echo "$value"
}

# Owner is inferred from the mountPoint, since that's where the literal
# service name survives interpolation. For Nextcloud and PostgreSQL, resolve
# the runtime UID from the actual container so we do not hardcode a guessed
# value (their UIDs are dynamically allocated by the respective NixOS
# modules, unlike acme/kanidm which use fixed shared UIDs).
owner_id_for() {
  local mount_point="$1"
  local container_name="${2:-}"
  case "$mount_point" in
    *kanidm*) echo "$KANIDM_ID" ;;
    *acme*) echo "$ACME_ID" ;;
    *nextcloud*)
      if [ -n "$container_name" ]; then
        local uid
        uid="$(nixos-container run "$container_name" -- id -u nextcloud 2>/dev/null || true)"
        if [[ "$uid" =~ ^[0-9]+$ ]]; then
          echo "$uid"
          return
        fi
      fi
      echo ""
      ;;
    *postgresql*)
      if [ -n "$container_name" ]; then
        local uid
        uid="$(nixos-container run "$container_name" -- id -u postgres 2>/dev/null || true)"
        if [[ "$uid" =~ ^[0-9]+$ ]]; then
          echo "$uid"
          return
        fi
      fi
      echo ""
      ;;
    *) echo "" ;;
  esac
}

set_owner() {
  local path="$1"
  local id="$2"
  if [ ! -d "$path" ]; then
    echo "Creating missing directory: $path"
    mkdir -p "$path"
  fi
  chown -R "${id}:${id}" "$path"
  # Fail fast if any file/dir underneath wasn't actually set to the expected owner
  if find "$path" ! -uid "$id" -o ! -gid "$id" | grep -q .; then
    echo "ERROR: ownership mismatch under $path (expected ${id}:${id})" >&2
    exit 1
  fi
  echo "OK: $path is owned by ${id}:${id}"
}

process_file() {
  local file="$1"
  echo "--- Processing $file ---"

  declare -A vars
  # Capture simple `name = "value";` and `name = 123;` bindings from the let block
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*\"([^\"]*)\"\; ]]; then
      vars["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    elif [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*([0-9]+)\; ]]; then
      vars["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
  done < <(sed -n '/^let/,/^in/p' "$file")

  local host_path=""
  local container_name=""
  if [ -n "${vars[workloadName]:-}" ] && [ -n "${vars[workloadNode]:-}" ]; then
    container_name="${vars[workloadName]}-${vars[workloadNode]}"
  fi

  while IFS= read -r line; do
    if [[ "$line" =~ hostPath[[:space:]]*=[[:space:]]*\"([^\"]*)\"\; ]]; then
      host_path="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ mountPoint[[:space:]]*=[[:space:]]*\"([^\"]*)\"\; ]] && [ -n "$host_path" ]; then
      local mount_point="${BASH_REMATCH[1]}"
      local resolved_path resolved_mount id
      resolved_path="$(resolve_nix_string "$host_path" vars)"
      resolved_mount="$(resolve_nix_string "$mount_point" vars)"
      id="$(owner_id_for "$resolved_mount" "$container_name")"
      if [ -z "$id" ]; then
        echo "WARN: could not determine owner for $resolved_path (mountPoint: $resolved_mount), skipping" >&2
      else
        set_owner "$resolved_path" "$id"
      fi
      host_path=""
    fi
  done < "$file"
}

for f in "$@"; do
  process_file "$f"
done
