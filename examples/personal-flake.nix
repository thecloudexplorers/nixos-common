{
  description = "Your personal use flake.";

  inputs = {
    # NOTE: Replace "nixos-YY.MM" with that which is in system.stateVersion of
    # configuration.nix. You can also use latter versions if you wish to
    # upgrade.
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-26.05";
    };
    # Enable lanzaboote for UEFI Secure Boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Load the community driven NixOS common definitions
    nixos-common.url = "github:thecloudexplorers/nixos-common/main";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      lanzaboote,
      nixos-common,
      ...
    }:
    {
      nixosConfigurations = {
        vm-nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit (self) inputs outputs; };
          modules = [
            {
              config = {
                _module = {
                  args = {
                    flake = self;
                  };
                };
              };
            }
            ({ ... }: {
              # The consumer only needs to provide the input and pass values into the module.
              inputs = {
                lanzaboote.url = "github:nix-community/lanzaboote";
              };

              # Example of overriding a specific path if they aren't using /var/lib/sbctl
              # services.common_modules.secureBoot.pkiBundle = "/etc/secureboot";
            })
            # Load nixos-common modules
            nixos-common.nixosModules.localization-en_nl
            nixos-common.nixosModules.secure-boot-tpm
            # Load your own local nix configuration
            ./your-modules/configuration.nix
          ];
        };
      };
    };
}
