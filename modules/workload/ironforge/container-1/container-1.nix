{ ... }:
let
  workloadName = "ironforge";
  workloadNode = 1;
  workloadService = "postgresql";
  rootDomain = "raboes28.nl";
in
{
  containers = {
    "${workloadName}-${toString workloadNode}" = {
      autoStart = true;
      privateUsers = "identity";
      bindMounts = {
        # Persist the PostgreSQL data directory.
        "/${workloadName}-data-lib-${workloadService}" = {
          hostPath = "/mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService}";
          mountPoint = "/var/lib/${workloadService}";
          isReadOnly = false;
        };
        # Persist PostgreSQL's logs.
        "/${workloadName}-data-log-${workloadService}" = {
          hostPath = "/mnt/ssd/${workloadName}/${toString workloadNode}/var/log/${workloadService}";
          mountPoint = "/var/log/${workloadService}";
          isReadOnly = false;
        };
        # Read the certificate issued centrally by the medivh ACME workload.
        # postgres is a member of the shared "acme" group (gid 966, see
        # modules/users/users/workloads/acme.nix), which the ACME module
        # grants group-read/traverse access to, so no copying or world
        # readable permissions are needed here.
        "/${workloadName}-acme-${workloadName}" = {
          hostPath = "/mnt/ssd/medivh/1/var/lib/acme/${workloadName}.${rootDomain}";
          mountPoint = "/var/lib/acme/${workloadName}.${rootDomain}";
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
