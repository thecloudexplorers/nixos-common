{ ... }:
let
  rootDomain = "raboes28.nl";
  workloadName = "heartstone";
  workloadNode = 1;
  workloadService = "kanidm";
  workloadDomain = "idm.${rootDomain}";
in
{
  containers = {
    "${workloadName}-${toString workloadNode}" = {
      autoStart = true;
      privateUsers = "identity";
      bindMounts = {
        # Store all workload service lib data that needs to be persisted
        # here as the container would not be persistent otherwise
        "/heartstone-data-lib-${workloadService}" = {
          hostPath = "/mnt/ssd/${workloadName}-${toString workloadNode}/var/lib/${workloadService}";
          mountPoint = "/var/lib/${workloadService}";
          isReadOnly = false;
        };
        "/heartstone-data-backups" = {
          hostPath = "/mnt/zdata/${workloadName}-${toString workloadNode}/backups";
          mountPoint = "/var/lib/${workloadService}/backups";
          isReadOnly = false;
        };
        # Read all external workload service config data (secrets) here
        # This allows staging of secrets (and certificates) in a
        # persistent manner while also offloading ACME requests
        # to a separate workload
        "/heartstone-secrets-acme" = {
          hostPath = "/mnt/ssd/${workloadName}-${toString workloadNode}/var/lib/acme/${workloadDomain}";
          mountPoint = "/var/lib/acme/${workloadDomain}";
          isReadOnly = true;
        };
      };
      # Ensure the container has a dedicated virtual interface
      privateNetwork = true;
      # Set the bridge as the host to networking
      hostBridge = "br0"; # TODODODODOD!!!
      config =
        { ... }:
        {
          imports = [
            # Profiles
            ../../../computer/profile/container.nix

            # Workload generic configurations
            ../workload.nix

            # Node specific configurations
            ./networking-1.nix
            ./service-kanidm-1.nix
          ];
        };
    };
  };
}
