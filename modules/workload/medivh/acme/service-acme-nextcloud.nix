{ ... }:
let
  workloadService = "acme";
  rootDomain = "raboes28.nl";
  certWorkload = "nextcloud";
  certDomain = "${certWorkload}.${rootDomain}";
in
{
  security = {
    "${workloadService}" = {
      certs = {
        "${certDomain}" = {
          domain = "${certDomain}";
          inheritDefaults = true;
          # The dalaran workload mounts this cert directory read-only and
          # runs its own nginx as a non-shared user (different uid namespace),
          # so both the directory and the cert material are made
          # world-readable/traversable instead of chown'd to a matching UID.
          postRun = ''
            chmod 755 .
            chmod 644 cert.pem fullchain.pem key.pem
          '';
        };
      };
    };
  };
}
