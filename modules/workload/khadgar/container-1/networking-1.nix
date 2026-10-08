{ lib, ... }:
let
  workloadName = "khadgar";
  workloadNode = 1;
  computerId = "ad3d76e4";
  computerName = "lxc-${workloadName}-${toString workloadNode}";
  ethernetInterfaceName = "eth0";
  # Reserve this address on the router so the proxy endpoints remain stable.
  ethernetInterfaceMacAddress = "02:6f:7f:e5:6e:70";
  # Only the HTTPS proxies are reachable: dashboard, API server and A2A.
  workloadTCPPorts = [
    9120
    8643
    9901
  ];
in
{
  networking = {
    hostId = computerId;
    hostName = computerName;
    enableIPv6 = lib.mkForce true;
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
