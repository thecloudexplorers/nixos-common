# on the HOST
sudo nixos-container root-login heartstone-1
journalctl -b -p 5


sudo nixos-container restart medivh-1
sudo systemctl stop container@heartstone-1
sudo systemctl start container@heartstone-1


ls -la /var/lib


sudo rm -rf /var/lib/nixos-containers/heartstone-1
sudo rm -rf  /var/lib/nixos-containers/medivh-1

sudo rm -rf /mnt/ssd/medivh
sudo rm -rf /mnt/ssd/heartstone
sudo rm -rf /mnt/zdata/heartstone
