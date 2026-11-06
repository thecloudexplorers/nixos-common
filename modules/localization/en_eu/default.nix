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
      timeZone = "Europe/Brussels";
    };

    # This specific configuration is intended to provide an English flavor
    # for people living in the Netherlands, that don't want Dutch as a base
    i18n = {
      # Use 'Computer English' as the default English language as
      # an international standard
      defaultLocale = cfg-lang.defaultLocaleShortlist;
      defaultCharset = cfg-lang.defaultCharsetShortlist;
      extraLocales = [
        "en_IE.UTF-8/UTF-8"
        "en_IE/ISO-8859-1"
        # en_IE@euro is intended to give solid English language support
        # with specific EU standard notations, like the DDMMYYY date format
        "en_IE@euro/ISO-8859-15"
      ];
      extraLocaleSettings = {
        LC_ADDRESS = "en_IE@euro";
        LC_COLLATE = "C.UTF-8";
        LC_CTYPE = "en_IE@euro";
        LC_IDENTIFICATION = "en_IE@euro";
        LC_MEASUREMENT = "en_IE@euro";
        LC_MESSAGES = "en_IE@euro";
        LC_MONETARY = "en_IE@euro";
        LC_NAME = "en_IE@euro";
        LC_NUMERIC = "en_IE@euro";
        LC_PAPER = "en_IE@euro";
        LC_TELEPHONE = "en_IE@euro";
        LC_TIME = "en_IE@euro";
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