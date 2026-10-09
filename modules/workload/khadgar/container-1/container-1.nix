# `inputs` are the flake inputs of the host; they are passed on to the container
# (see `specialArgs` below) to import the Hermes Agent NixOS module.
{ inputs, ... }:
let
  rootDomain = "raboes28.nl";
  workloadName = "khadgar";
  workloadNode = 1;
  workloadService = "hermes";
  workloadDomain = "${workloadName}.${rootDomain}";
in
{
  containers = {
    "${workloadName}-${toString workloadNode}" = {
      autoStart = true;
      privateUsers = "identity";
      bindMounts = {
        # Persist the Hermes state on the host.
        "/${workloadName}-data-lib-${workloadService}" = {
          hostPath = "/mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService}";
          mountPoint = "/var/lib/${workloadService}";
          isReadOnly = false;
        };
        # API keys and dashboard credentials (hermes.env), kept out of the Nix store.
        "/${workloadName}-secrets-${workloadService}" = {
          hostPath = "/mnt/ssd/${workloadName}/${toString workloadNode}/secrets/${workloadService}";
          mountPoint = "/tmp/${workloadName}-${workloadService}";
          isReadOnly = true;
        };
        # Use the centrally managed certificate for the HTTPS proxies.
        "/${workloadName}-acme-${workloadService}" = {
          hostPath = "/mnt/ssd/medivh/1/var/lib/acme/${workloadDomain}";
          mountPoint = "/var/lib/acme/${workloadDomain}";
          isReadOnly = true;
        };
      };
      privateNetwork = true;
      hostBridge = "br0";
      # The container evaluates separately from the host, so the flake inputs
      # must be handed over explicitly.
      specialArgs = { inherit inputs; };
      config =
        { ... }:
        {
          imports = [
            # Profiles
            ../../../computer/profile/container.nix

            # Workload specific configurations
            ../workload.nix

            # Container instance specific configurations
            ./networking-1.nix
          ];
        };
    };
  };
}
