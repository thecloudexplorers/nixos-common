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
  # Ironforge-1's LAN IP, set via a DHCP reservation on the router (see
  # modules/workload/ironforge/container-1/networking-1.nix for its MAC).
  # Resolved as a static hosts entry rather than relying on public DNS:
  # systemd-resolved refuses to route arbitrary-domain queries (like
  # ironforge.raboes28.nl) through the router's DHCP-provided DNS server
  # here, since that link's DNS routing domain isn't the default route
  # ("~."), causing "No appropriate name servers or networks for name
  # found" errors.
  ironforgeWorkloadAddressIPv4 = "192.168.1.112";
  ironforgeWorkloadHostName = "ironforge.raboes28.nl";

in
{
  networking = {
    hostId = computerId;
    hostName = computerName;
    enableIPv6 = lib.mkForce true;
    # Use systemd-resolved inside the container.
    # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
    useHostResolvConf = lib.mkForce false;
    extraHosts = ''
      ${ironforgeWorkloadAddressIPv4} ${ironforgeWorkloadHostName}
    '';
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
