{ config, lib, ... }: {
	imports = [ ];

	options = {
		time = {
			offsetHardwareClock = lib.mkOption {
				description =
					"Offset the hardware (system) clock to the local timezone?";
				type = lib.types.bool;
				default = false;
			};
		};

		i18n = {
			defaultLocaleShortlist = lib.mkOption {
				description = "The default locale for this config.";
				type = lib.types.enum [
					"C.UTF-8"
					"en_IE.UTF-8"
					"en_IE.ISO-8859-1"
					"en_IE@euro.ISO-8859-15"
					"nl_NL.UTF-8"
					"nl_NL.ISO-8859-1"
					"nl_NL@euro.ISO-8859-15"
				];
				default = "C.UTF-8";
			};
			defaultCharsetShortlist = lib.mkOption {
				description = "The default charset for this config.";
				type = lib.types.enum [ "UTF-8" "ISO-8859-1" "ISO-8859-15" ];
				default = "UTF-8";
			};
		};
	};

	config = let
		cfg-time = config.time;
		cfg-lang = config.i18n;
	in {
		# Set your time zone
		time = {
			hardwareClockInLocalTime = cfg-time.offsetHardwareClock;
			# Set Amsterdam as default timezone as a 'default Europe timezone'
			timeZone = "Europe/Amsterdam";
		};

		# This specific configuration is intended to provide an English flavor
		# for people living in the Netherlands, that don't want Dutch as a base
		i18n = {
			# Use 'Computer English' as the default English language as
			# an international standard
			defaultLocale = cfg-lang.defaultLocaleShortlist;
			defaultCharset = cfg-lang.defaultCharsetShortlist;
			extraLocales = [ "en_IE.UTF-8/UTF-8" "nl_NL.UTF-8/UTF-8" ];
			extraLocaleSettings = {
				LC_ADDRESS = "nl_NL.UTF-8";
				LC_COLLATE = "C.UTF-8";
				LC_CTYPE = "en_IE.UTF-8";
				LC_IDENTIFICATION = "en_IE.UTF-8";
				LC_MEASUREMENT = "nl_NL.UTF-8";
				LC_MESSAGES = "en_IE.UTF-8";
				LC_MONETARY = "nl_NL.UTF-8";
				LC_NAME = "en_IE.UTF-8";
				LC_NUMERIC = "nl_NL.UTF-8";
				LC_PAPER = "nl_NL.UTF-8";
				LC_TELEPHONE = "nl_NL.UTF-8";
				LC_TIME = "nl_NL.UTF-8";
			};
			# Set all supported charsets to the UTF-8 set to
			# enable neutral charsets, combined with NL/EU locale
			localeCharsets = {
				LC_ADDRESS = "UTF-8";
				# C only supports UTF-8, not an ISO standard.
				LC_COLLATE = "UTF-8";
				LC_CTYPE = "UTF-8";
				LC_IDENTIFICATION = "UTF-8";
				LC_MEASUREMENT = "UTF-8";
				LC_MESSAGES = "UTF-8";
				LC_MONETARY = "UTF-8";
				LC_NAME = "UTF-8";
				LC_NUMERIC = "UTF-8";
				LC_PAPER = "UTF-8";
				LC_TELEPHONE = "UTF-8";
				LC_TIME = "UTF-8";
			};
		};
	};
}
