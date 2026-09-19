{ ... }:
let
  workloadName = "dalaran";
  workloadNode = 1;
  workloadService = "nextcloud";
in
{
  containers = {
    "${workloadName}-${toString workloadNode}" = {
      autoStart = true;
      timeoutStartSec = "15min";
      privateUsers = "identity";
      bindMounts = {
        # Persist the Nextcloud home directory.
        "/${workloadName}-data-lib-${workloadService}" = {
          hostPath = "/mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService}";
          mountPoint = "/var/lib/${workloadService}";
          isReadOnly = false;
        };
        # Store the Nextcloud data set separately on the data volume.
        "/${workloadName}-data-lib-${workloadService}-data" = {
          hostPath = "/mnt/zdata/${workloadName}/${toString workloadNode}/var/lib/${workloadService}/data";
          mountPoint = "/var/lib/${workloadService}/data";
          isReadOnly = false;
        };
        # Read ACME-issued certificate material for the service.
        "/${workloadName}-acme-${workloadService}" = {
          hostPath = "/mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/acme";
          mountPoint = "/var/lib/acme";
          isReadOnly = false;
        };
        # Bootstrap the initial Nextcloud admin password.
        "/${workloadName}-secrets-admin-${workloadService}" = {
          hostPath = "/mnt/ssd/${workloadName}/${toString workloadNode}/secrets/admin";
          mountPoint = "/tmp/${workloadName}-admin";
          isReadOnly = true;
        };
      };
      privateNetwork = true;
      hostBridge = "br0";
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
