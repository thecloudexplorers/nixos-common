{
  config,
  lib,
  ...
}:
{
  imports = [ ];

  options = {
    time = {
      offsetHardwareClock = lib.mkOption {
        description = "Offset the hardware (system) clock to the local timezone?";
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
          "en_IE"
          "en_IE@euro"
          "nl_NL.UTF-8"
          "nl_NL"
          "nl_NL@euro"
        ];
        default = "C.UTF-8";
      };
      defaultCharsetShortlist = lib.mkOption {
        description = "The default charset for this config.";  
        type = lib.types.enum [
          "UTF-8"
          "ISO-8859-1"
          "ISO-8859-15"
        ];
        default = "UTF-8";
      };
    };
  };

  config =
  let
    cfg-time = config.time;
    cfg-lang = config.i18n;
  in
  {
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
      extraLocales = [
        # en_IE@euro is intended to give solid English language support
        # with specific EU standard notations, like the DDMMYYY date format
        "en_IE@euro/ISO-8859-15"
        # The ISO-8859-1 standard is a good English language choice,
        # but lacks specific NL characters and the Euro sign
        "nl_NL/ISO-8859-1"
        # The ISO-8859-15 standard will allow for a clear English
        # language choice, with solid NL character set support
        "nl_NL@euro/ISO-8859-15"
      ];
      extraLocaleSettings = {
        LC_ADDRESS = "nl_NL@euro";
        LC_COLLATE = "C.UTF-8";
        LC_CTYPE = "en_IE@euro";
        LC_IDENTIFICATION = "en_IE@euro";
        LC_MEASUREMENT = "nl_NL@euro";
        LC_MESSAGES = "en_IE@euro";
        LC_MONETARY = "nl_NL@euro";
        LC_NAME = "en_IE@euro";
        LC_NUMERIC = "nl_NL@euro";
        LC_PAPER = "nl_NL@euro";
        LC_TELEPHONE = "nl_NL@euro";
        LC_TIME = "nl_NL@euro";
      };
      # Set all supported charsets to the ISO-8859-15 set to
      # enable the Euro character and several EU language specifics
      localeCharsets = {
        LC_ADDRESS = "ISO-8859-15";
        # C only support UTF-8, not an ISO standard.
        LC_COLLATE = "UTF-8";
        LC_CTYPE = "ISO-8859-15";
        LC_IDENTIFICATION = "ISO-8859-15";
        LC_MEASUREMENT = "ISO-8859-15";
        LC_MESSAGES = "ISO-8859-15";
        LC_MONETARY = "ISO-8859-15";
        LC_NAME = "ISO-8859-15";
        LC_NUMERIC = "ISO-8859-15";
        LC_PAPER = "ISO-8859-15";
        LC_TELEPHONE = "ISO-8859-15";
        LC_TIME = "ISO-8859-15";
      };
    };
  };
}