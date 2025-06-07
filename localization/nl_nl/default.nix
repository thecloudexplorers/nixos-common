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
          "nl_NL.UTF-8"
          "nl_NL"
          "nl_NL@euro"
        ];
        default = "nl_NL@euro";
      };
      defaultCharsetShortlist = lib.mkOption {
        description = "The default charset for this config.";  
        type = lib.types.enum [
          "UTF-8"
          "ISO-8859-1"
          "ISO-8859-15"
        ];
        default = "ISO-8859-15";
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

    # This specific configuration is intended to provide an all Dutch flavor
    # for people living in the Netherlands, want Dutch as a base as well
    i18n = {
      defaultLocale = cfg-lang.defaultLocaleShortlist;
      defaultCharset = cfg-lang.defaultCharsetShortlist;
      extraLocales = [
        # The ISO-8859-1 standard is a good Dutch language choice,
        # but lacks specific NL characters and the Euro sign
        "nl_NL/ISO-8859-1"
        # The ISO-8859-15 standard will allow for a clear Dutch
        # language choice, with solid NL character set support
        "nl_NL@euro/ISO-8859-15"
      ];
      extraLocaleSettings = {
        LC_ADDRESS = "nl_NL@euro";
        LC_COLLATE = "nl_NL@euro";
        LC_CTYPE = "nl_NL@euro";
        LC_IDENTIFICATION = "nl_NL@euro";
        LC_MEASUREMENT = "nl_NL@euro";
        LC_MESSAGES = "nl_NL@euro";
        LC_MONETARY = "nl_NL@euro";
        LC_NAME = "nl_NL@euro";
        LC_NUMERIC = "nl_NL@euro";
        LC_PAPER = "nl_NL@euro";
        LC_TELEPHONE = "nl_NL@euro";
        LC_TIME = "nl_NL@euro";
      };
      # Set all supported charsets to the ISO-8859-15 set to
      # enable the Euro character and several EU language specifics
      localeCharsets = {
        LC_ADDRESS = "ISO-8859-15";
        LC_COLLATE = "ISO-8859-15";
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