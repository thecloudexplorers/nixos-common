{ ... }:
let
  workloadName = "ironforge";
  workloadNode = 1;
  workloadService = "postgresql";
in
{
  containers = {
    "${workloadName}-${toString workloadNode}" = {
      autoStart = true;
      privateUsers = "identity";
      bindMounts = {
        # Persist the PostgreSQL data directory. Its "secrets" subdirectory
        # (/var/lib/postgresql/secrets) is populated externally: medivh's
        # ACME postRun hook writes the cert/key for ironforge.raboes28.nl
        # into the same host path via its own separate, writable bind mount
        # (see modules/workload/medivh/container-1/container-1.nix and
        # modules/workload/medivh/acme/service-acme-ironforge.nix), already
        # owned by postgres (uid/gid 71, a fixed nixpkgs system id shared
        # across containers via modules/users/users/workloads/postgres.nix).
        # This avoids postgres needing direct read access to the ACME
        # mount, since PostgreSQL enforces that ssl_key_file be owned by
        # the database user (or root) -- group-read access alone (as used
        # for nginx/kanidm) is not sufficient.
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
