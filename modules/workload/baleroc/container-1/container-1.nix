{ ... }:
let
  workloadName = "baleroc";
  workloadNode = 1;
  rootDomain = "raboes28.nl";
in
{
  containers = {
    "${workloadName}-${toString workloadNode}" = {
      autoStart = true;
      privateUsers = "identity";
      bindMounts = {
        # Read the certificate issued centrally by the medivh ACME workload.
        # nginx is a member of the shared "acme" group (gid 966, see
        # modules/users/users/workloads/acme.nix), which the ACME module
        # grants group-read/traverse access to. The proxy is public facing,
        # so this is mounted read-only: a compromise of this container must
        # not be able to alter certificates or keys.
        "/${workloadName}-acme-nextcloud" = {
          hostPath = "/mnt/ssd/medivh/1/var/lib/acme/nextcloud.${rootDomain}";
          mountPoint = "/var/lib/acme/nextcloud.${rootDomain}";
          isReadOnly = true;
        };
        # Same for the Kanidm (idm) certificate. Medivh writes it into
        # heartstone's ACME directory (see
        # modules/workload/heartstone/host-data.nix), so it is read from there.
        "/${workloadName}-acme-idm" = {
          hostPath = "/mnt/ssd/heartstone/var/lib/acme/idm.${rootDomain}";
          mountPoint = "/var/lib/acme/idm.${rootDomain}";
          isReadOnly = true;
        };
      };
      # Ensure the container has a dedicated virtual interface
      privateNetwork = true;
      # Set the bridge as the host to networking
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
