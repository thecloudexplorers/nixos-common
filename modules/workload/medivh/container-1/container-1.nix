{ ... }:
let
  workloadName = "medivh";
  workloadNode = 1;
  workloadService = "acme";
  rootDomain = "raboes28.nl";
  heartstoneWorkloadName = "heartstone";
  heartstoneWorkloadService = "kanidm";
  hearstoneWorkloadDomain = "idm.${rootDomain}";
in
{
  containers = {
    "${workloadName}-${toString workloadNode}" = {
      autoStart = true;
      timeoutStartSec = "15min";
      privateUsers = "identity";
      bindMounts = {
        # All workload service app data to be stored here
        "/${workloadService}/lib" = {
          hostPath = "/mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService}";
          mountPoint = "/var/lib/${workloadService}";
          isReadOnly = false;
        };
        # All workload service log files to be stored here
        "/${workloadService}/log" = {
          hostPath = "/mnt/ssd/${workloadName}/${toString workloadNode}/var/log/${workloadService}";
          mountPoint = "/var/log/${workloadService}";
          isReadOnly = false;
        };
        # Read the external workload service transip env config from here
        "/${workloadService}/environments" = {
          hostPath = "/mnt/ssd/${workloadName}/environments";
          mountPoint = "/var/lib/${workloadService}/environments";
          isReadOnly = true;
        };
        # Read the external workload service transip secret from here
        "/${workloadService}/secrets" = {
          hostPath = "/mnt/ssd/${workloadName}/secrets";
          mountPoint = "/var/lib/${workloadService}/secrets";
          isReadOnly = true;
        };
        # Store the external certificates here
        "/certs/${heartstoneWorkloadName}" = {
          hostPath = "/mnt/ssd/${heartstoneWorkloadName}/var/lib/${workloadService}/${hearstoneWorkloadDomain}";
          mountPoint = "/var/lib/${workloadService}/${hearstoneWorkloadDomain}";
          isReadOnly = false;
        };
        "/soulstone-data-lib-private-${heartstoneWorkloadService}" = {
          hostPath = "/mnt/ssd/${heartstoneWorkloadName}/var/lib/${heartstoneWorkloadService}/secrets";
          mountPoint = "/var/lib/private/${heartstoneWorkloadService}";
          isReadOnly = false;
        };
      };
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
