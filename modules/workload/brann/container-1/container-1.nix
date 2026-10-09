{ ... }:
let
  rootDomain = "raboes28.nl";
  workloadName = "brann";
  workloadNode = 1;
  workloadService = "open-webui";
  workloadDomain = "brann.${rootDomain}";
in
{
  containers = {
    "${workloadName}-${toString workloadNode}" = {
      autoStart = true;
      privateUsers = "identity";
      bindMounts = {
        # Persist the Open WebUI state (database, uploads, session secret).
        # The service uses a systemd DynamicUser with StateDirectory, which
        # keeps its data in /var/lib/private/<name>, so the mount goes there.
        "/${workloadName}-data-lib-${workloadService}" = {
          hostPath = "/mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService}";
          mountPoint = "/var/lib/private/${workloadService}";
          isReadOnly = false;
        };
        # Use the centrally managed certificate for the HTTPS proxy.
        "/${workloadName}-acme-${workloadService}" = {
          hostPath = "/mnt/ssd/medivh/1/var/lib/acme/${workloadDomain}";
          mountPoint = "/var/lib/acme/${workloadDomain}";
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
