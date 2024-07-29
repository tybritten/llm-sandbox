#!/bin/bash
#install microk8s
sudo snap install microk8s --channel=1.29/stable --classic
sudo microk8s status --wait-ready
sudo snap install kubectl --classic

IPADDR=$(ip -4 -j route | jq -r '.[] | select(.dst | contains("default")) | .prefsrc')

mkdir -p .kube
sudo chown -R $USER .kube
sudo usermod -a -G microk8s ubuntu
sudo microk8s config > .kube/config

curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.21.5 sh -
export PATH="$PATH:/home/$USER/istio-1.21.5/bin"

#enable microk8s addons metal lb and nvidia gpu operator
sudo microk8s.enable metallb:$IPADDR-$IPADDR
sudo microk8s enable nvidia --gpu-operator-driver host

# add open webui and mldm helm repos
sudo microk8s helm3 repo add open-webui https://helm.openwebui.com/
sudo microk8s helm3 repo add pach http://helm.pachyderm.com
sudo microk8s helm3 repo update

#enable mayastor and minio
sudo microk8s enable core/mayastor --default-pool-size 100G 
sudo microk8s enable minio -c 50Gi -s mayastor

echo "Add the Minio username and pasword to the environment variables"
echo "also add the MLDM enterprise license key to the environment variables"
echo "as well as a docker user and token that can access the MLIS containers"
echo "before running the next script setup_3.sh"
echo "export MINIO_KEY=\"<username>\""
echo "export MINIO_SECRET=\"<password>\""
echo "export MLDM_LICENSE_KEY=\"<license_key>\""
echo "export DOCKER_USER=\"<docker_user>\""
echo "export DOCKER_TOKEN=\"<docker_token>\""
echo ""


