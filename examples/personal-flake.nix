{
  description = "Your personal use flake.";

  inputs = {
    # NOTE: Replace "nixos-YY.MM" with that which is in system.stateVersion of
    # configuration.nix. You can also use latter versions if you wish to
    # upgrade.
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-26.05";
    };
    # Enable lanzaboote for UEFI Secure Boot. The secure-boot-tpm module
    # imports the lanzaboote NixOS module through the `inputs` module
    # argument, which is wired up via specialArgs below.
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
          # Pass the flake inputs to all modules as the `inputs` argument;
          # secure-boot-tpm uses inputs.lanzaboote to import lanzaboote.
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
            # Load nixos-common modules
            nixos-common.nixosModules.nix-base
            nixos-common.nixosModules.localization-en_nl
            nixos-common.nixosModules.secure-boot-tpm
            # Optional: override the secure boot parameters.
            # The module declares these as options; defaults are enable = true
            # and pkiBundle = "/var/lib/sbctl".
            # {
            #   tce.services.common-modules.secureBoot = {
            #     pkiBundle = "/etc/secureboot";
            #   };
            # }
            # Load your own local nix configuration
            ./your-modules/configuration.nix
          ];
        };
      };
    };
}
