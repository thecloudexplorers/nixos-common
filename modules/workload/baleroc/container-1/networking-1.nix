{ lib, ... }:
let
  workloadName = "baleroc";
  workloadNode = 1;
  # Generate hostId by machine ID: `head -c 8 /etc/machine-id`
  # Generate hostId at random: `head -c4 /dev/urandom | od -A none -t x4`
  computerId = "c3e8a5f7";
  computerName = "lxc-${workloadName}-${toString workloadNode}";
  ethernetInterfaceName = "eth0";
  # Fill this in after deployment of the container, and create a DHCP
  # reservation for it on the router. The router port forwards (80/443) and
  # dalaran's Nextcloud `trusted_proxies` both point at this address.
  ethernetInterfaceMacAddress = "aa:e1:bd:dd:d2:40";
  workloadTCPPorts = [
    80 # Only used to redirect to HTTPS.
    443 # The public facing reverse proxy.
  ];
in
{
  networking = {
    hostId = computerId;
    hostName = computerName;
    interfaces = {
      "${ethernetInterfaceName}" = {
        name = ethernetInterfaceName;
        macAddress = ethernetInterfaceMacAddress;
        useDHCP = lib.mkForce true;
        tempAddress = "disabled";
      };
    };
    firewall = {
      enable = true;
      allowedTCPPorts = workloadTCPPorts;
    };
  };
}
