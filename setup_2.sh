#!/bin/bash
set -e
set -x

#install microk8s
sudo snap install microk8s --channel=1.29/stable --classic
sudo microk8s status --wait-ready
sudo snap install kubectl --classic


if [[ -z "${IPADDR}" ]]; then
	export IPADDR=$(ip -4 -j route | jq -r '.[] | select(.dst | contains("default")) | .prefsrc')
fi

mkdir -p ~/.kube
sudo chown -R $USER ~/.kube
sudo usermod -a -G microk8s $USER
sudo microk8s config > ~/.kube/config

pushd $HOME  # Ensure that istio installs into the users HOME
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.21.5 sh -
export PATH="$PATH:/home/$USER/istio-1.21.5/bin"
popd

#enable microk8s addons metal lb and nvidia gpu operator
sudo microk8s enable metallb:$IPADDR-$IPADDR
sudo microk8s enable nvidia --gpu-operator-driver host

# add open webui and mldm helm repos
sudo microk8s helm3 repo add open-webui https://helm.openwebui.com/
sudo microk8s helm3 repo add pach http://helm.pachyderm.com
sudo microk8s helm3 repo update

#enable mayastor and minio
sudo microk8s enable core/mayastor --default-pool-size 100G 
sudo microk8s enable minio -c 50Gi -s mayastor

set +x
echo "Add the Minio username and pasword to the environment variables"
echo "export MINIO_KEY=\"<username>\""
echo "export MINIO_SECRET=\"<password>\""
echo "also add the MLDM enterprise license key to the environment variables"
echo "export MLDM_LICENSE_KEY=\"<mldm license_key>\""
echo ""
echo "set PUBLIC_DNS to the dns name for the server. you can also use <ip address>.nip.io."
echo "export PULBIC_DNS=\"<dns name>\""
echo ""
echo "you can now run setup_3.sh"

