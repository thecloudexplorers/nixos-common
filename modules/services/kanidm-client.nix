{
  flake.modules.nixos.services-kanidm-client =
    {
      pkgs,
      ...
    }:
    let
      primary_domain = "idm.raboes28.nl";

    in
    {
      services = {
        kanidm = {
          package = pkgs.kanidm_1_11;
          client = {
            enable = true;
            settings.uri = "https://${primary_domain}";
          };
        };
      };
    };
}
