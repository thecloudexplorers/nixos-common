{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    # Load the community driven NixOS hardware definitions
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # NOTE: Ensure disko is here to get filesystem information into the flake
    disko = {
      url = "github:nix-community/disko/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      nixos-generators,
      nixos-hardware,
      disko,
      home-manager,
      plasma-manager,
      ...
    }:
    {
      packages.x86_64-linux = {
        usbInstallerMinimal = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          modules = [
            {
              # Pin nixpkgs to the flake input, so that the packages installed
              # come from the flake inputs.nixpkgs.url.
              nix.registry.nixpkgs.flake = nixpkgs;
            }
            ./generators/installation/minimal.nix
          ];
          format = "iso";
        };
        usbInstallerFull = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          modules = [
            {
              # Pin nixpkgs to the flake input, so that the packages installed
              # come from the flake inputs.nixpkgs.url.
              nix.registry.nixpkgs.flake = nixpkgs;
            }
            ./generators/installation/full.nix
          ];
          format = "iso";
        };
      };
      # The actual computers/servers config starts here, with module imports.
      nixosConfigurations = {
        faml-pc-home_server = nixpkgs.lib.nixosSystem {
          # NOTE: Change this to aarch64-linux if you are on ARM
          system = "x86_64-linux";
          specialArgs = { inherit (self) inputs outputs; };
          modules = [
            {
              config = {
                _module = {
                  args = {
                    flake = self;
                    customHostName = "faml-pc-home_server";
                    stateVersion = "26.05";
                  };
                };
              };
            }
            # Enable disko so configuration.nix can import the disk-config.nix configuration
            disko.nixosModules.default
            # Load nixos-hardware modules for this specific device
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-cpu-amd-pstate
            nixos-hardware.nixosModules.common-gpu-amd
            nixos-hardware.nixosModules.common-pc
            nixos-hardware.nixosModules.common-pc-ssd
            # Load the various modules through the configuration.nix imports
            ./modules/computer/server/faml-pc-home_server/configuration.nix
          ];
        };
      };
    };
}
