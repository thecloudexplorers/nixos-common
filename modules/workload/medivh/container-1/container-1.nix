{ ... }:
let
  rootDomain = "raboes28.nl";
  workloadName = "medivh";
  workloadNode = 1;
  workloadService = "acme";
  heartstoneWorkloadName = "heartstone";
  heartstoneWorkloadNode = 1;
  heartstoneWorkloadService = "kanidm";
  heartstoneWorkloadDomain = "idm.${rootDomain}";
  ironforgeWorkloadName = "ironforge";
  ironforgeWorkloadNode = 1;
  ironforgeWorkloadService = "postgresql";
  ironforgeWorkloadDomain = "ironforge.${rootDomain}";
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
          hostPath = "/mnt/ssd/${heartstoneWorkloadName}/var/lib/${workloadService}/${heartstoneWorkloadDomain}";
          mountPoint = "/var/lib/${workloadService}/${heartstoneWorkloadDomain}";
          isReadOnly = false;
        };
        "/soulstone-data-lib-private-${heartstoneWorkloadService}" = {
          hostPath = "/mnt/ssd/${heartstoneWorkloadName}/${toString heartstoneWorkloadNode}/var/lib/${heartstoneWorkloadService}/secrets";
          mountPoint = "/var/lib/private/${heartstoneWorkloadService}";
          isReadOnly = false;
        };
        # Store the external ironforge.${rootDomain} certificate here, in a
        # location postgres itself owns (postgres enforces that its ssl_key_file
        # be owned by the database user or root, so it cannot read directly out
        # of the read-only ACME mount the way nginx/kanidm's group-read access
        # does). See modules/workload/medivh/acme/service-acme-ironforge.nix's
        # postRun for the copy/chown step, and this same host path is bind
        # mounted inside ironforge-1 at /var/lib/postgresql/secrets.
        "/ironforge-data-lib-private-${ironforgeWorkloadService}" = {
          hostPath = "/mnt/ssd/${ironforgeWorkloadName}/${toString ironforgeWorkloadNode}/var/lib/${ironforgeWorkloadService}/secrets";
          mountPoint = "/var/lib/private/${ironforgeWorkloadService}";
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
