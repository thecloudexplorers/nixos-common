{ ... }:
let
  workloadName = "dalaran";
  workloadNode = 1;
  workloadService = "nextcloud";
  rootDomain = "raboes28.nl";
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
        # Read the certificate issued centrally by the medivh ACME workload.
        # nginx is a member of the shared "acme" group (gid 966, see
        # modules/users/users/workloads/acme.nix), which the ACME module
        # grants group-read/traverse access to, so no copying or world
        # readable permissions are needed here.
        "/${workloadName}-acme-${workloadService}" = {
          hostPath = "/mnt/ssd/medivh/1/var/lib/acme/nextcloud.${rootDomain}";
          mountPoint = "/var/lib/acme/nextcloud.${rootDomain}";
          isReadOnly = true;
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
