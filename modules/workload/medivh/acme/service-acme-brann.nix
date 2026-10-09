{ ... }:
let
  workloadService = "acme";
  rootDomain = "raboes28.nl";
  certDomain = "brann.${rootDomain}";
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
