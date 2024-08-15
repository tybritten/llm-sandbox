#!/bin/bash
if [[ -z "${MINIO_KEY}" ]]; then
  echo "MINIO_KEY is undefined"
  exit 1
elif [[ -z "${MINIO_SECRET}" ]]; then
  echo "MINIO_SECRET is undefined"
  exit 1
fi

MLIS_NAMESPACE="mlis"

set -e
set -x

sudo microk8s kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.1/cert-manager.yaml

export PATH="$PATH:/home/$USER/istio-1.21.5/bin"
mkdir -p ~/.kube
sudo microk8s config > ~/.kube/config
istioctl install -y

sudo microk8s kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.13.1/serving-crds.yaml

sudo microk8s kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.13.1/serving-core.yaml
sleep 10
sudo microk8s kubectl apply -f https://github.com/knative/net-istio/releases/download/knative-v1.13.1/net-istio.yaml


sudo microk8s kubectl run -n minio-operator mc --restart=Never --image=minio/mc --command -- /bin/sh -c 'while true; do sleep 5s; done'
sleep 10
sudo microk8s kubectl exec -n minio-operator --stdin --tty mc -- mc alias set microk8s http://minio:80 $MINIO_KEY $MINIO_SECRET
sudo microk8s kubectl exec -n minio-operator --stdin --tty mc -- mc mb -p microk8s/pach
sudo microk8s kubectl exec -n minio-operator --stdin --tty mc -- mc mb -p microk8s/models
sudo microk8s kubectl delete pod -n minio-operator mc

if [[ -z "${PUBLIC_DNS}" ]]; then
	export PUBLIC_DNS=$(curl -s http://icanhazip.com).nip.io
fi
if [[ -z "${MLDM_LICENSE_KEY}" ]]; then
	export MLDM_LICENSE_KEY=""
fi

cat > mldm-values.yaml << EOF
deployTarget: MINIO
proxy:
  host: $PUBLIC_DNS
  enabled: true
  service:
    type: NodePort
pachd:
  enterpriseLicenseKey: $MLDM_LICENSE_KEY
  activateAuth: false
  storage:
    backend: AMAZON
    gocdkEnabled: true
    storageURL: "s3://pach?endpoint=minio.minio-operator.svc.cluster.local:80&disableSSL=true&region=us-east-1"
    amazon:
      id: "$MINIO_KEY"
      secret: "$MINIO_SECRET"
EOF

sudo microk8s helm3 upgrade -i mldm pach/pachyderm -f mldm-values.yaml


sudo microk8s kubectl apply -f https://github.com/kserve/kserve/releases/download/v0.13.0/kserve.yaml


cat << 'EOF' > mlis-values.yaml
defaultPassword: HPE2024Password
global:
  imagePullSecrets:
  - name: my-registry-secret
proxy:
  type: NodePort
EOF


# Create mlis Name space
set +e +x
OUT=$(sudo microk8s kubectl create ns "${MLIS_NAMESPACE}" 2>&1)
RETCODE=$?
if [[ $RETCODE -ne 0 ]]; then
	if [[ "${OUT}" == *"AlreadyExists"* ]]; then
		echo "Namespace '${MLIS_NAMESPACE}' already exists. Continuing"
	else
		echo "Create namespace failed: ${OUT}" 1>&2
	fi
fi
set -e -x

sudo microk8s helm3 upgrade -i open-webui open-webui/open-webui -n open-webui --create-namespace \
    --set ollama.enabled=false --set pipelines.enabled=false --set service.type=NodePort --set servive.nodePort=30081

set +x
echo "OpenWebUI and MLDM are installed as well as the prerequisites for MLIS."
echo "you can reach the UI of MLDM at http://${PUBLIC_DNS}:30080"
echo "you can reach the UI of OpenWebUI at http://${PUBLIC_DNS}:30081"
echo "To install MLIS, you'll need a a MSC license key, MLIS SKU from MSC, and your MLIS license key and email"
echo "before running the next script setup_4.sh"
echo "if you do not have MSC access for MLIS but have the chart downloaded and extracted at aioli/ and docker repo access,"
echo "export your docker username as MSC_EMAIL and your token as MLIS_LICENSE_KEY and"
echo "run the script setup_4_docker.sh"
echo "export MSC_EMAIL=\"<email address>\""
echo "export MLIS_LICENSE_KEY=\"<license key>\""
echo "export MLIS_SKU=\"<MLIS SKU>\""
