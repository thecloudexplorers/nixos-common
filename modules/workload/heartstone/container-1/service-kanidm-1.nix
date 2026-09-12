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
    bindaddress = "0.0.0.0:${toString workloadServicePort}";
    ldapbindaddress = "0.0.0.0:${toString workloadServiceLdapPort}";
  };
  # Option B (didn't work): bind to listeningAddressIPv4 directly and wait for
  # DHCP to assign it before starting, instead of binding to 0.0.0.0 above.
  # bindaddress = "${listeningAddressIPv4}:${toString workloadServicePort}";
  # ldapbindaddress = "${listeningAddressIPv4}:${toString workloadServiceLdapPort}";
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
