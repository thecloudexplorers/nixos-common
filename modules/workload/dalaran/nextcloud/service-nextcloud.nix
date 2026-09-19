{ pkgs, ... }:
let
  workloadName = "dalaran";
  workloadService = "nextcloud";
  rootDomain = "raboes28.nl";
  workloadHostName = "${workloadService}.${rootDomain}";
  workloadAdminPasswordFile = "/tmp/${workloadName}-admin/${workloadService}-admin-pass";
  workloadDataDirectory = "/var/lib/${workloadService}/data";
in
{
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;
    hostName = workloadHostName;
    home = "/var/lib/${workloadService}";
    datadir = workloadDataDirectory;
    database.createLocally = true;
    configureRedis = true;
    https = true;
    autoUpdateApps.enable = true;
    maxUploadSize = "16G";
    config = {
      adminuser = "admin";
      adminpassFile = workloadAdminPasswordFile;
      dbtype = "pgsql";
      dbname = workloadService;
      dbuser = workloadService;
    };
    settings = {
      trusted_domains = [ workloadHostName ];
      overwriteprotocol = "https";
      default_phone_region = "NL";
      allow_local_remote_servers = true;
      log_type = "file";
      maintenance = false;
      maintenance_window_start = 1;
      "profile.enabled" = true;
    };
    phpOptions = {
      "opcache.interned_strings_buffer" = "32";
      "opcache.memory_consumption" = "2048";
      "opcache.revalidate_freq" = "60";
      "max_input_time" = "3600";
      "max_execution_time" = "3600";
      "upload_tmp_dir" = "${workloadDataDirectory}/big_temp_file/";
    };
  };
}
