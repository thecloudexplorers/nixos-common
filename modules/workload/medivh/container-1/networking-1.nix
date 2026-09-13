{ ... }:
let
  workloadName = "medivh";
  workloadNode = 1;
  # Generate hostId by machine ID: `head -c 8 /etc/machine-id`
  # Generate hostId at random: `head -c4 /dev/urandom | od -A none -t x4`
  computerId = "8c552aff";
  computerName = "lxc-${workloadName}-${toString workloadNode}";
in
{
  networking = {
    hostId = computerId;
    hostName = computerName;
  };
}
