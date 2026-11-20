# Create NixOS installer images

USB installer ISOs are built as flake `packages` with plain `nixpkgs.lib.nixosSystem`, taking the image from `config.system.build.isoImage`. The deprecated `nixos-generators` is not used.

## Flake approach

See `packages.x86_64-linux` in [flake.nix](../flake.nix). Each installer is the ISO output of a `nixosSystem` whose modules include `./generators/installation/<name>.nix`, which imports the nixpkgs installer profile (`installation-cd-minimal.nix` or `installation-cd-base.nix`).

Build an image with:
`nix build ~/path/to/repo#usbInstallerFull`

>NOTE: `usbInstallerFull` is the name of the package defined in the flake.nix

The ISO ends up in `./result/iso/<file>.iso`.

## ISO data dump to USB drive

In order to write the ISO image to a thumb drive, the `dd` utility (also known as 'disk destroyer', 'disk duplicator', or 'data dump') can be used.

The following command will write the ISO image to a thumbdrive:
`sudo dd if=/path/to/nixos-installer.iso of=/dev/sdX bs=4M conv=fsync oflag=direct status=progress`

Be sure to replace the `if` parameter with the correct source, and the `of` parameter with the correct target drive.

> Take note! The targeted disk will be erased, do not swap the parameters around. Or you will find out why the tool is referred to as the 'disk destroyer'.
