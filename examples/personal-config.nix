{
  config,
  imports,
  inputs,
  ...
}:
let
  repo = builtins.fetchGit {
    url = "https://github.com/thecloudexplorers/nixos-common.git";
    rev = "commit-hash"; # Replace with the specific commit hash you want to use
  };
in
{
  imports = [
    # This is the 'Contract'. One line to import all your work.
    "${repo}/modules/boot/secure-boot-tpm.nix"
  ];

  # The consumer only needs to provide the input and pass values into the module.
  inputs = {
    lanzaboote.url = "github:nix-community/lanzaboote";
  };

  # Example of overriding a specific path if they aren't using /var/lib/sbctl
  # services.common_modules.secureBoot.pkiBundle = "/etc/secureboot";
}
