{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    # Load the community driven NixOS hardware definitions
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    # NOTE: Ensure disko is here to get filesystem information into the flake
    disko = {
      url = "github:nix-community/disko/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Enable lanzaboote for UEFI Secure Boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Load the community driven NixOS common module catalog
    nix-modules-catalog = {
      url = "github:thecloudexplorers/nix-modules-catalog/main";
    };
    # Manage per-user configuration (dotfiles, programs) declaratively
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Manage KDE Plasma desktop settings through home-manager
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    # Hermes Agent and its NixOS module, used by the khadgar workload. It is
    # intentionally not made to follow our nixpkgs, because the agent's Python
    # and Node dependencies are built against the nixpkgs it ships with.
    hermes-agent.url = "github:NousResearch/hermes-agent";
  };
  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
      disko,
      nix-modules-catalog,
      home-manager,
      plasma-manager,
      ...
    }:
    {
      # The ISOs are built with plain nixosSystem; the generator modules import
      # the nixpkgs installer profiles that provide `isoImage`.
      packages.x86_64-linux = {
        usbInstallerMinimal =
          (nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              {
                # Pin nixpkgs to the flake input, so that the packages installed
                # come from the flake inputs.nixpkgs.url.
                nix.registry.nixpkgs.flake = nixpkgs;
              }
              ./generators/installation/minimal.nix
            ];
          }).config.system.build.isoImage;
        usbInstallerFull =
          (nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              {
                # Pin nixpkgs to the flake input, so that the packages installed
                # come from the flake inputs.nixpkgs.url.
                nix.registry.nixpkgs.flake = nixpkgs;
              }
              ./generators/installation/full.nix
            ];
          }).config.system.build.isoImage;
      };
      # Provide a project-local Nix development environment for editor tooling.
      # This ensures VS Code/Nix IDE has a stable `nixd` LSP server and
      # `nixfmt` formatter available from the flake instead of depending on
      # whatever happens to be installed globally on the host machine.
      devShells.x86_64-linux.default =
        let
          pkgs = import nixpkgs {
            system = "x86_64-linux";
          };
        in
        pkgs.mkShell {
          packages = with pkgs; [
            nixd
            nixfmt
          ];
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
            # Load nix-modules-catalog modules
            nix-modules-catalog.nixosModules.nix-base
            nix-modules-catalog.nixosModules.secure-boot-tpm
            # Load the various modules through the configuration.nix imports
            ./modules/computer/server/faml-pc-home_server/configuration.nix
          ];
        };
      };
    };
}
