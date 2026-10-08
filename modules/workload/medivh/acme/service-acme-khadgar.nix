{ ... }:
let
  workloadService = "acme";
  rootDomain = "raboes28.nl";
  certDomain = "khadgar.${rootDomain}";
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
