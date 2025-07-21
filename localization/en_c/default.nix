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
        ];
        default = "C.UTF-8";
      };
      defaultCharsetShortlist = lib.mkOption {
        description = "The default charset for this config.";  
        type = lib.types.enum [
          "UTF-8"
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
      # Use UTC as default timezone for globally neutral configuration
      timeZone = "UTC";
    };

    # This specific configuration provides a globally neutral computer English
    # locale based on C.UTF-8 for maximum universal compatibility
    i18n = {
      # Use C.UTF-8 as the default locale for globally neutral computer English
      defaultLocale = cfg-lang.defaultLocaleShortlist;
      defaultCharset = cfg-lang.defaultCharsetShortlist;
      extraLocales = [
        "en_US.UTF-8/UTF-8"
      ];
      extraLocaleSettings = {
        LC_ADDRESS = "C.UTF-8";
        LC_COLLATE = "C.UTF-8";
        LC_CTYPE = "C.UTF-8";
        LC_IDENTIFICATION = "C.UTF-8";
        LC_MEASUREMENT = "C.UTF-8";
        LC_MESSAGES = "C.UTF-8";
        LC_MONETARY = "C.UTF-8";
        LC_NAME = "C.UTF-8";
        LC_NUMERIC = "C.UTF-8";
        LC_PAPER = "C.UTF-8";
        LC_TELEPHONE = "C.UTF-8";
        LC_TIME = "C.UTF-8";
      };
      # Set all supported charsets to UTF-8 for maximum compatibility
      localeCharsets = {
        LC_ADDRESS = "UTF-8";
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