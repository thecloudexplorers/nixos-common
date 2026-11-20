# Dev flow: testing local changes with `--override-input`

You consume nixos-common as a flake input:

```nix
inputs.nixos-common.url = "github:thecloudexplorers/nixos-common/main";
```

`flake.lock` pins that input to a remote revision, so edits in a local clone
are invisible to your config until you push. To evaluate or build against the
local working tree instead — without committing and without touching the lock —
override the input for a single command:

```bash
# Evaluate an option of your host while using the LOCAL nixos-common
nix eval \
  --no-write-lock-file \
  --override-input nixos-common path:/home/you/src/nixos-common \
  .#nixosConfigurations.myhost.config.system.stateVersion --json

# Read-only full build of a host against the local nixos-common
nix build \
  --no-write-lock-file \
  --override-input nixos-common path:/home/you/src/nixos-common \
  .#nixosConfigurations.myhost.config.system.build.toplevel

# List the hosts your flake defines
nix eval \
  --no-write-lock-file \
  --override-input nixos-common path:/home/you/src/nixos-common \
  .#nixosConfigurations --apply 'builtins.attrNames' --json

# Check the library itself (it has no inputs, plain nix works there)
cd /home/you/src/nixos-common && nix flake check
```

## How it works, and caveats

- `--override-input <name> <url>` resolves input `<name>` from `<url>` for this
  invocation only. `flake.lock` is not modified — add `--no-write-lock-file`
  on commands that might otherwise save the lock (`nix build`,
  `nix flake check`).
- `path:` copies the local directory into the store, so evaluation sees
  exactly what is on disk. For a dirty git tree nix copies the working tree
  as-is (warning: "Git tree ... is dirty"): uncommitted edits, new untracked
  files, and deletions are all reflected.
- `path:` URLs must not traverse a symlink (`error: path '...' is a symlink`).
  Resolve the real path first, e.g. `path:$(readlink -f ~/src/nixos-common)`.
- The override URL can be any flake URL: `path:...`, `git+file://...`,
  `github:owner/repo/<sha>`, etc. — handy to test against a specific remote
  commit or a fork.
- Overriding an input your flake does not have is only a warning, not an
  error.
- nix only accepts `--override-input` *after* the subcommand
  (`nix --override-input ... eval` fails with "unrecognised flag"), so to
  avoid retyping the flags, wrap them in a shell function:

  ```bash
  nixdev() {
    local subcmd="$1"
    shift
    nix "$subcmd" --no-write-lock-file \
      --override-input nixos-common "path:$(readlink -f "$HOME/src/nixos-common")" \
      "$@"
  }
  # usage: nixdev eval .#nixosConfigurations --apply 'builtins.attrNames' --json
  #        nixdev build .#nixosConfigurations.myhost.config.system.build.toplevel
  ```

- Once your change is pushed, make consumers use it permanently with
  `nix flake lock --update-input nixos-common` in the consumer flake. Until
  then, plain `nix eval`/`nix build` without overrides still uses the old
  locked revision.

## Non-flake consumers

If you import modules via `builtins.fetchGit` (see
`examples/personal-config.nix`), the equivalent is pointing the fetch at your
local clone, or importing the module files by plain path:

```nix
# Option A: fetch the local clone (git+file keeps it a flake-style source)
repo = builtins.fetchGit { url = "git+file:///home/you/src/nixos-common"; };

# Option B: import the module file directly from the local path
imports = [ /home/you/src/nixos-common/modules/nix/base.nix ];
```
