{ lib, ... }:
let
  workloadName = "dalaran";
  workloadNode = 1;
  computerId = "a4f1d0b2";
  computerName = "lxc-${workloadName}-${toString workloadNode}";
  ethernetInterfaceName = "eth0";
  workloadTCPPorts = [
    443 # The only open port outside of the container.
    18443 # The remote accessible port.
  ];
  workloadUDPPorts = [
    3478 # Required for Talk.
  ];

in
{
  networking = {
    hostId = computerId;
    hostName = computerName;
    enableIPv6 = lib.mkForce true;
    # Use systemd-resolved inside the container.
    # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
    useHostResolvConf = lib.mkForce false;
    interfaces = {
      "${ethernetInterfaceName}" = {
        name = ethernetInterfaceName;
        useDHCP = lib.mkForce true;
        tempAddress = "disabled";
      };
    };
    firewall = {
      # Enable or disable the firewall altogether.
      enable = true;
      # Open ports in the firewall.
      allowedTCPPorts = workloadTCPPorts;
      allowedUDPPorts = workloadUDPPorts;
    };
    networkmanager = {
      # Disable networkmanager as it may interfere with DHCP
      # Set all specifics in separate modules
      enable = lib.mkForce false;
    };
  };
}
