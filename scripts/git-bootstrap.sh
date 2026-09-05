git config --global user.name "Jev"
git config --global user.email "32514140+devjevnl@users.noreply.github.com"
git config --global core.editor "code --wait"
ssh-keygen -t ed25519 -C "32514140+devjevnl@users.noreply.github.com" -f \~/.ssh/github-authentication

eval "$(ssh-agent -s)"
ssh-add \~/.ssh/github-authentication
cat \~/.ssh/github-authentication.pub
ssh-add -l -E sha256
ssh -vT git@github.com
ssh-keygen -t ed25519 -C "32514140+devjevnl@users.noreply.github.com" -f \~/.ssh/github-signing

eval "$(ssh-agent -s)"
git config --global user.signingkey \~/.ssh/github-signing.pub
cat \~/.ssh/github-signing.pub
echo "32514140+devjevnl@users.noreply.github.com $(cat \~/.ssh/github-signing.pub)" > \~/.config/git/allowed_signers

git config --global gpg.ssh.allowedSignersFile \~/.config/git/allowed_signers
git config --global gpg.format ssh
git config --global commit.gpgsign false
git config --global tag.gpgsign false
git config --global init.defaultBranch main

git config --local user.name "Jev"
git config --local user.email "32514140+devjevnl@users.noreply.github.com"
git config --local user.signingkey  \~/.ssh/signing-github.pub
