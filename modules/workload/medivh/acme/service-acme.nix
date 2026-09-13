{ ... }:
let
  workloadService = "acme";
  workloadServiceUser = workloadService;
  workloadServiceGroup = workloadServiceUser;
  letsEncryptStaging = false;
  letsEncryptUrlSuffix = "v02.api.letsencrypt.org/directory";
  letsEncryptAccUrl = "https://${workloadService}-staging-${letsEncryptUrlSuffix}";
  letsEncryptProdUrl = "https://${workloadService}-${letsEncryptUrlSuffix}";
  letsEncryptUrl = if letsEncryptStaging then letsEncryptAccUrl else letsEncryptProdUrl;
  acmeEnvironmentFile = "/var/lib/${workloadService}/environments/acme-transip-env";
  rootDomain = "raboes28.nl";
  acmeDefaultEmail = "jev+le@${rootDomain}";
in
{
  security = {
    "${workloadService}" = {
      acceptTerms = true;
      defaults = {
        dnsPropagationCheck = true;
        dnsProvider = "transip";
        dnsResolver = "195.135.195.195:53";
        environmentFile = acmeEnvironmentFile;
        email = acmeDefaultEmail;
        group = workloadServiceGroup;
        # Supported: rsa2048, rsa3072, rsa4096, rsa8192, ec256, ec384.
        keyType = "ec256";
        renewInterval = "daily";
        renewJitter = "6h";
        validMinDays = 9;
        server = letsEncryptUrl;
      };
      maxConcurrentRenewals = 3;
      useRoot = false;
    };
  };
}
