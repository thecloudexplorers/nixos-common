# `config` is the host configuration; it is used below to reuse the host's NVIDIA driver.
{ config, ... }:
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
        # Persist Ollama service state on the host. The models live in the
        # `models` subdirectory of this mount, so they are on the SSD too: it is
        # much faster than the zdata pool at loading a model into VRAM.
        "/${workloadName}-data-lib-${workloadService}" = {
          hostPath = "/mnt/ssd/${workloadName}/${toString workloadNode}/var/lib/${workloadService}";
          mountPoint = "/var/lib/private/${workloadService}";
          isReadOnly = false;
        };
        # Expose the NVIDIA device nodes so Ollama (CUDA) can use the host GPU.
        # /dev/dri is not needed for CUDA, so it is not passed in.
        "/${workloadName}-dev-nvidia0" = {
          hostPath = "/dev/nvidia0";
          mountPoint = "/dev/nvidia0";
          isReadOnly = false;
        };
        "/${workloadName}-dev-nvidiactl" = {
          hostPath = "/dev/nvidiactl";
          mountPoint = "/dev/nvidiactl";
          isReadOnly = false;
        };
        "/${workloadName}-dev-nvidia-uvm" = {
          hostPath = "/dev/nvidia-uvm";
          mountPoint = "/dev/nvidia-uvm";
          isReadOnly = false;
        };
        # Use the centrally managed certificate for the HTTPS proxy.
        "/${workloadName}-acme-${workloadService}" = {
          hostPath = "/mnt/ssd/medivh/1/var/lib/acme/${workloadDomain}";
          mountPoint = "/var/lib/acme/${workloadDomain}";
          isReadOnly = true;
        };
      };
      # Bind mounting a device node is not enough: the container's device cgroup
      # must also allow access to it.
      allowedDevices = [
        {
          node = "/dev/nvidia0";
          modifier = "rw";
        }
        {
          node = "/dev/nvidiactl";
          modifier = "rw";
        }
        {
          node = "/dev/nvidia-uvm";
          modifier = "rw";
        }
      ];
      privateNetwork = true;
      hostBridge = "br0";
      config =
        { pkgs, ... }:
        {
          imports = [
            # Profiles
            ../../../computer/profile/container.nix

            # Workload specific configurations
            ../workload.nix

            # Container instance specific configurations
            ./networking-1.nix
          ];

          # The container evaluates its packages separately from the host, so the
          # proprietary NVIDIA/CUDA packages must be allowed here as well.
          nixpkgs.config.allowUnfree = true;

          # The userspace libraries (libcuda, libnvidia-ml) must match the host's
          # kernel driver version exactly, otherwise NVML fails with "Driver/library
          # version mismatch". Reuse the host's pinned driver package instead of a
          # separate one from this container's nixpkgs. This links the libraries
          # into /run/opengl-driver, where CUDA applications look for them.
          # The `.out` output must be named explicitly: the package's default
          # output is `bin`, which only holds the tools and no libcuda, so Ollama
          # would silently fall back to the CPU.
          hardware.graphics = {
            enable = true;
            extraPackages = [ config.hardware.nvidia.package.out ];
          };

          # nvidia-smi from the same driver package, for verification.
          environment.systemPackages = [ config.hardware.nvidia.package.bin ];
        };
    };
  };
}
