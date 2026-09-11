{ ... }:
{
  # Shared user & group config for all containers
  users =
    let
      unixUserName = "acme";
      unixGroupName = unixUserName;
      # https://systemd.io/UIDS-GIDS/
      # Pick an unused system ID. Not in the range of kanidm. But ensure
      # is also doesn't overlap with regular users in any case.
      # Created using `shuf -i 1879048192-2147352575 -n 1`
      unixGidNumber = 2114071989;
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
          extraGroups = [
            "sharedstorage"
          ];
        };
      };
    };
}
