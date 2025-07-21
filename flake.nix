{
  description = "nixos-common";

  outputs = _: {
    nixosModules =
      let
       # Needed to allow the module system to import these modules
        import = path: path;
      in
      {
        localization-en_c = import ./localization/en_c;
        localization-en_eu = import ./localization/en_eu;
        localization-en_nl = import ./localization/en_nl;
        localization-nl_nl = import ./localization/nl_nl;
      };
  };
}