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
          # runs its own nginx as a non-shared user, so the cert material
          # is made world-readable instead of chown'd to a matching UID.
          postRun = ''
            chmod 644 cert.pem fullchain.pem key.pem
          '';
        };
      };
    };
  };
}
