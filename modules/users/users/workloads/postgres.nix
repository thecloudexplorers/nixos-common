{ ... }:
{
  # Shared user & group config for all containers
  #
  # PostgreSQL is unusual among this repo's workloads in that nixpkgs
  # assigns it a well-known, fixed system uid/gid (see
  # config.ids.uids.postgres / config.ids.gids.postgres in
  # nixos/modules/misc/ids.nix), rather than dynamically allocating one.
  # Declaring the same fixed uid/gid here (mirroring kanidm.nix/acme.nix)
  # lets a "postgres" user exist consistently across containers that don't
  # run PostgreSQL themselves (e.g. medivh), so cross-container bind mounts
  # populated by medivh's ACME postRun hooks can be chowned to the exact
  # uid PostgreSQL itself will run as inside ironforge-1.
  users =
    let
      unixUserName = "postgres";
      unixGroupName = unixUserName;
      unixGidNumber = 71;
    in
    {
      groups = {
        "${unixGroupName}" = {
          name = unixGroupName;
          gid = unixGidNumber;
        };
      };
      users = {
        "${unixUserName}" = {
          enable = true;
          name = unixUserName;
          uid = unixGidNumber;
          group = unixGroupName;
          isSystemUser = true;
        };
      };
    };
}
