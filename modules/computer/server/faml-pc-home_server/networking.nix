{ customHostName, lib, ... }:
let
  computerId = "8bda2338";
  ethernetInterfaceName = "enp11s0";
  ethernetInterfaceMacAddress = "30:c5:99:5d:16:7f";
  #ethernetInterfaceName = "enp12s0";
  #wirelessInterface = "wlp10s0";
  bridgeInterfaceName = "br0";
  bridgeInterfaceMacAddress = "30:c5:99:5d:16:7f";
  bridgePhysicalInterface = ethernetInterfaceName;
  bridgeStaticIPv4Address = "192.168.1.66";
  bridgeStaticIPv6Address = "2a02:a441:f08f:0:32c5:99ff:fe5d:167f";
  dhcpcdDenyInterfaces = [
    ethernetInterfaceName
    "vb-heartstone-1"
  ];
in
{
  networking = {
    # Generate hostId by machine: `head -c 8 /etc/machine-id`
    # Generate hostId at random: `head -c4 /dev/urandom | od -A none -t x4`
    hostId = computerId;
    hostName = customHostName;
    enableIPv6 = true;
    resolvconf = {
      enable = true;
      dnsExtensionMechanism = true;
      dnsSingleRequest = false;
      useLocalResolver = false;
    };
    useDHCP = true;
    # DO NOT allow DHCP to configure the upstream NIC (we need the bridge)
    # DO NOT allow DHCP to configure the veth interfaces per container
    dhcpcd.denyInterfaces = dhcpcdDenyInterfaces;
    bridges."${bridgeInterfaceName}".interfaces = [ bridgePhysicalInterface ];
    interfaces = {
      # No DHCP as this interface serves as the bridge
      "${bridgePhysicalInterface}" = {
        name = ethernetInterfaceName;
        macAddress = ethernetInterfaceMacAddress;
        useDHCP = lib.mkForce false;
      };
      "${bridgeInterfaceName}" = {
        name = bridgeInterfaceName;
        macAddress = bridgeInterfaceMacAddress;
        # Do not use the DHCP server/router to set the IP address.
        # Issues with bridge stability & connectivity in the past.
        useDHCP = lib.mkForce true;
        # Ensure IPv6 only uses a dedicated address, no "privacy extensions"
        tempAddress = "disabled";
        # Set container-ip for IPv4 static, in case DHCP fails
        ipv4 = {
          addresses = [
            {
              address = bridgeStaticIPv4Address;
              prefixLength = 24;
            }
          ];
        };
        # Set container-ip for IPv6 static, in case DHCP fails
        ipv6 = {
          addresses = [
            {
              address = bridgeStaticIPv6Address;
              prefixLength = 64;
            }
          ];
        };
      };
    };
    firewall.enable = true;
    # Disable networkmanager as it may interfere with the bridge
    # Set all specifics in separate modules
    networkmanager.enable = lib.mkForce false;
  };
}
