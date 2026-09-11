{ ... }:
let
  workloadName = "medivh";
  workloadService = "acme";
  rootDomain = "raboes28.nl";
in
{
  containers = {
    "${workloadName}" = {
      autoStart = true;
      timeoutStartSec = "15min";
      privateUsers = "identity";
      bindMounts = {
        # All workload service app data to be stored here
        "/${workloadService}/lib" = {
          hostPath = "/mnt/ssd/${workloadName}/var/lib/${workloadService}";
          mountPoint = "/var/lib/${workloadService}";
          isReadOnly = false;
        };
        # All workload service log files to be stored here
        "/${workloadService}/log" = {
          hostPath = "/mnt/ssd/${workloadName}/var/log/${workloadService}";
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
        # Store the external idm.${rootDomain} certificates here
        "/certs/idm.${rootDomain}" = {
          hostPath = "/mnt/ssd/heartstone/1/var/lib/acme/idm.${rootDomain}";
          mountPoint = "/var/lib/acme/idm.${rootDomain}";
          isReadOnly = false;
        };
        "/soulstone-data-lib-private-kanidm" = {
          hostPath = "/mnt/ssd/heartstone/1/var/lib/kanidm/secrets";
          mountPoint = "/var/lib/private/kanidm";
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
