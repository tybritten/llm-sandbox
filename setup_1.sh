#!/bin/bash
sudo apt-get update

# hugepages needed for storaeg
sudo sysctl vm.nr_hugepages=1024
echo 'vm.nr_hugepages=1024' | sudo tee -a /etc/sysctl.conf


#download nvidia drivers and modules for nvme
sudo apt install -y ubuntu-drivers-common 
sudo apt install -y linux-modules-extra-$(uname -r)

#install python and pip for mlis cli
sudo apt install -y python3-pip python3.12-venv
python3 -m venv venv

# nmve-tcp needed for mayastor
sudo modprobe nvme_tcp
echo 'nvme-tcp' | sudo tee -a /etc/modules-load.d/microk8s-mayastor.conf

#install nvidia drivers
sudo ubuntu-drivers install

sudo reboot
