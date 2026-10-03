{ ... }:
let
  workloadService = "acme";
  rootDomain = "raboes28.nl";
  certDomain = "ollama.${rootDomain}";
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
