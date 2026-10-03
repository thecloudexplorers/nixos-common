{ ... }:
let
  rootDomain = "raboes28.nl";
  workloadName = "cho";
  workloadNode = 1;
  workloadService = "ollama";
  workloadDomain = "ollama.${rootDomain}";
in
{
  containers = {
    "${workloadName}-${toString workloadNode}" = {
      autoStart = true;
      privateUsers = "identity";
      bindMounts = {
        # Persist Ollama service state on the host.
        "/${workloadName}-data-lib-${workloadService}" = {
          hostPath = "/mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService}";
          mountPoint = "/var/lib/private/${workloadService}";
          isReadOnly = false;
        };
        # Store the large model files on the data volume.
        "/${workloadName}-models-${workloadService}" = {
          hostPath = "/mnt/zdata/${workloadName}/${toString workloadNode}/var/lib/${workloadService}/models";
          mountPoint = "/var/lib/private/${workloadService}/models";
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
