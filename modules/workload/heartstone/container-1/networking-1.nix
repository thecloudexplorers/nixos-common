{ lib, ... }:
let
  workloadName = "heartstone";
  workloadNode = 1;
  # Generate hostId by machine ID: `head -c 8 /etc/machine-id`
  # Generate hostId at random: `head -c4 /dev/urandom | od -A none -t x4`
  computerId = "5a717d57";
  computerName = "lxc-${workloadName}-${toString workloadNode}";
  ethernetInterfaceName = "eth0";
  # TODO: The MAC address is still commented out, so this container gets a
  # random MAC and the DHCP reservation on the router is not stable. Fill it
  # in after deployment of the container, uncomment it here and below, and
  # set the reservation on the router.
  # Fill this in after deployment of the container!!!
  # ethernetInterfaceMacAddress = "c2:51:cd:8e:23:01";
  workloadTCPPorts = [ ];
in
{
  networking = {
    hostId = computerId;
    hostName = computerName;
    interfaces = {
      "${ethernetInterfaceName}" = {
        name = ethernetInterfaceName;
        # macAddress = ethernetInterfaceMacAddress;
        useDHCP = lib.mkForce true;
        tempAddress = "disabled";
      };
    };
    firewall.allowedTCPPorts = workloadTCPPorts;
    firewall.allowedUDPPorts = workloadTCPPorts;
  };
}
