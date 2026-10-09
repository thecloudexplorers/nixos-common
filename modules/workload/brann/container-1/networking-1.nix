{ lib, ... }:
let
  workloadName = "brann";
  workloadNode = 1;
  computerId = "e1c47b92";
  computerName = "lxc-${workloadName}-${toString workloadNode}";
  ethernetInterfaceName = "eth0";
  # Reserve this address on the router so the web interface endpoint remains stable.
  ethernetInterfaceMacAddress = "02:b4:a1:7e:3c:5d";
  workloadTCPPorts = [ 443 ];
  # Heartstone-1's LAN IP, set via a DHCP reservation on the router (MAC
  # c2:51:cd:8e:23:01). Open WebUI does a direct OIDC discovery call to
  # https://idm.raboes28.nl from inside the brann container, so it needs a
  # stable local host entry instead of relying on the router's DNS domain route.
  kanidmAddressIPv4 = "192.168.1.209";
  # Stable SLAAC (EUI-64) address derived from heartstone-1's MAC.
  kanidmAddressIPv6 = "2a02:a441:f08f:0:c051:cdff:fe8e:2301";
  # Cho-1's LAN IP, set via a DHCP reservation on the router (MAC
  # 02:38:9a:9f:02:ab). Open WebUI calls Ollama at https://ollama.raboes28.nl
  # from inside this container, which cannot resolve that name through the
  # router's DNS.
  choAddressIPv4 = "192.168.1.31";
  # Stable SLAAC (EUI-64) address derived from cho-1's MAC.
  choAddressIPv6 = "2a02:a441:f08f:0:38:9aff:fe9f:2ab";
in
{
  networking = {
    hostId = computerId;
    hostName = computerName;
    enableIPv6 = lib.mkForce true;
    # Use systemd-resolved inside the container, but inject the private IdP and
    # Ollama hosts directly. The router's DHCP-provided DNS domain is not enough
    # here: the SSO login performs OIDC discovery before the browser callback,
    # and Open WebUI calls Ollama on every model request.
    useHostResolvConf = lib.mkForce false;
    extraHosts = ''
      ${kanidmAddressIPv4} idm.raboes28.nl
      ${kanidmAddressIPv6} idm.raboes28.nl
      ${choAddressIPv4} ollama.raboes28.nl
      ${choAddressIPv6} ollama.raboes28.nl
    '';
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
