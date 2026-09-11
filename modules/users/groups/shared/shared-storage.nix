{ ... }:
{
  # Shared user & group config for all containers
  users =
    let
      unixGroupName = "sharedstorage";
      # https://systemd.io/UIDS-GIDS/
      # Pick an unused system ID. Not in the range of kanidm. But ensure
      # is also doesn't overlap with regular users in any case.
      # Created using `shuf -i 1879048192-2147352575 -n 1`
      unixGidNumber = 1961558808;
    in
    {
      groups = {
        "${unixGroupName}" = {
          name = unixGroupName;
          gid = unixGidNumber;
        };
      };
    };
}
