{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, nixos-generators, ... }: {
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
  };
}
