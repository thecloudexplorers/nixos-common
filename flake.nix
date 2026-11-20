{
	description = "nixos-common";

	outputs = _: {
		nixosModules = let
			# Needed to allow the module system to import these modules
			import = path: path;
		in {
			nix-base = import ./modules/nix/base.nix;
			localization-en_c = import ./modules/localization/en_c;
			localization-en_eu = import ./modules/localization/en_eu;
			localization-en_nl = import ./modules/localization/en_nl;
			localization-en_nl_euro = import ./modules/localization/en_nl/euro;
			localization-en_nl_utf8 = import ./modules/localization/en_nl/utf8;
			localization-nl_nl = import ./modules/localization/nl_nl;
      secure-boot-tpm = import ./modules/boot/secure-boot-tpm.nix;
		};
	};
}
