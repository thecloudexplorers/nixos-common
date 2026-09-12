{ ... }:
let
  workloadService = "kanidm";
  listeningAddressIPv4 = "192.168.1.209";
  workloadServicePort = 443;
  workloadServiceLdapPort = 636;
in
{
  services."${workloadService}".server.settings = {
    role = "WriteReplica";
    bindaddress = "${listeningAddressIPv4}:${toString workloadServicePort}";
    ldapbindaddress = "${listeningAddressIPv4}:${toString workloadServiceLdapPort}";
  };
  # # Wait for DHCP to actually assign ${listeningAddressIPv4} before binding to it
  # systemd.services."${workloadService}" = {
  #   after = [ "network-online.target" ];
  #   wants = [ "network-online.target" ];
  # };
  networking.firewall.allowedTCPPorts = [
    workloadServicePort
    workloadServiceLdapPort
  ];
  networking.firewall.allowedUDPPorts = [
    workloadServicePort
    workloadServiceLdapPort
  ];
}
