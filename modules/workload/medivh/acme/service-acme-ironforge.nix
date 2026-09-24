{ ... }:
let
  workloadService = "acme";
  rootDomain = "raboes28.nl";
  certWorkload = "ironforge";
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
