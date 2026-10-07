{ lib, ... }:
let
  workloadName = "heartstone";
  workloadNode = 1;
  # Generate hostId by machine ID: `head -c 8 /etc/machine-id`
  # Generate hostId at random: `head -c4 /dev/urandom | od -A none -t x4`
  computerId = "5a717d57";
  computerName = "lxc-${workloadName}-${toString workloadNode}";
  ethernetInterfaceName = "eth0";
  # Fixed MAC address so the DHCP reservation on the router (192.168.1.209)
  # stays stable. Baleroc's static hosts entries for idm.raboes28.nl use this
  # address and its SLAAC (EUI-64) IPv6 address derived from this MAC, see
  # ../../baleroc/service-nginx.nix. Changing the MAC requires updating both.
  ethernetInterfaceMacAddress = "c2:51:cd:8e:23:01";
  workloadTCPPorts = [ ];
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
    firewall.allowedTCPPorts = workloadTCPPorts;
    firewall.allowedUDPPorts = workloadTCPPorts;
  };
}
