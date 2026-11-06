# Classic (non-flake) consumer configuration for nixos-common.
#
# The secure-boot-tpm module imports lanzaboote via the `inputs` module
# argument, and NixOS `imports` may not depend on config, so `inputs`
# must be passed as specialArgs at the nixosSystem entrypoint:
#
#   # default.nix
#   let
#     lanzabooteSrc = builtins.fetchGit {
#       url = "https://github.com/nix-community/lanzaboote.git";
#       rev = "commit-hash"; # Replace with the specific commit hash you want to use
#     };
#   in
#   (import <nixpkgs> { }).lib.nixosSystem {
#     modules = [ ./personal-config.nix ];
#     specialArgs.inputs.lanzaboote.nixosModules.lanzaboote =
#       import "${lanzabooteSrc}/nix/modules/lanzaboote.nix";
#   }
{
  imports =
    let
      repo = builtins.fetchGit {
        url = "https://github.com/thecloudexplorers/nixos-common.git";
        rev = "commit-hash"; # Replace with the specific commit hash you want to use
      };
    in
    [
      # This is the 'Contract'. One line to import all your work.
      "${repo}/modules/boot/secure-boot-tpm.nix"
    ];

  # Optional: override the secure boot parameters.
  # The module declares these as options; defaults are enable = true
  # and pkiBundle = "/var/lib/sbctl".
  # services.common_modules.secureBoot.pkiBundle = "/etc/secureboot";
}
