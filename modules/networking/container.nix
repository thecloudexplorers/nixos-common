{ lib, ... }:
let
  ethernetInterfaceName = "eth0";
in
{
  # Shared networking config for all containers
  networking = {
    domain = "raboes28.nl";
    # Ensure the default gateway is tied to the correct interface (internal to the container)
    defaultGateway = {
      address = lib.mkDefault "192.168.1.1";
      interface = lib.mkDefault "${ethernetInterfaceName}";
    };
    nameservers = lib.mkDefault [ "192.168.1.1" ];
    useDHCP = lib.mkDefault true;
    enableIPv6 = lib.mkDefault true;
    # Disable networkmanager as it may interfere with DHCP
    # Set all specifics in separate modules
    networkmanager.enable = lib.mkDefault false;
    # Use systemd-resolved inside the container
    # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
    useHostResolvConf = lib.mkForce false;
  };
  services.resolved.enable = lib.mkDefault true;
}
