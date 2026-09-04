# Rebuild based on configuration.nix updates with switch
nixos-rebuild switch

# Building the NixImage
cd /home/jev/dev/nixos-config/
nix build .#usbInstallerFull

# Generate SSH Key for github
ssh-keygen -t ed25519 -C "32514140+devjevnl@users.noreply.github.com" -f ~/.ssh/github-authentication

# Get public Key to paste in github
cat ~/.ssh/github-authentication.pub

#Clone GitHub Repo using ssh
git clone git@github.com:devjevnl/nixos-config.git --config core.sshCommand="ssh -i ~/.ssh/github-authentication"