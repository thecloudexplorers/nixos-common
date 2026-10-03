{ lib, ... }:
let
  workloadName = "cho";
  workloadNode = 1;
  computerId = "7061963f";
  computerName = "lxc-${workloadName}-${toString workloadNode}";
  ethernetInterfaceName = "eth0";
  # Reserve this address on the router so the proxy endpoint remains stable.
  ethernetInterfaceMacAddress = "02:38:9a:9f:02:ab";
  workloadTCPPorts = [ 443 ];
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
