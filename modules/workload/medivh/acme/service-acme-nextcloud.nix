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
        };
      };
    };
  };
}
