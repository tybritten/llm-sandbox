#!/bin/bash
if [[ -z "${MSC_EMAIL}" ]]; then
  echo "MSC_EMAIL is undefined. This should be your docker username"
  exit 1
elif [[ -z "${MLIS_LICENSE_KEY}" ]]; then
  echo "MLIS_LICENSE_KEY is undefined. This should be your docker token"
  exit 1
fi
if [[ ! -d "$PWD/aioli" ]]; then
	echo "Could not find Aioli directory here ${PWD}/aioli. Have you downloaded and extracted the helm chart?" 1>&2
    exit 1
fi

set -e
set -x

# (Re)Create secret
set +e +x
SECRET_NAME="my-registry-secret"
sudo microk8s kubectl describe secret -n "${MLIS_NAMESPACE}" "${SECRET_NAME}" > /dev/null
RETCODE=$?
if [[ $RETCODE == 0 ]]; then
	echo "secret \"${SECRET_NAME}\" already exists, removing."
	sudo microk8s kubectl delete secret -n "${MLIS_NAMESPACE}" "${SECRET_NAME}" ||
		(echo "Failed to delete secret" && exit 1)
fi
sudo microk8s kubectl create secret docker-registry -n "${MLIS_NAMESPACE}" "${SECRET_NAME}" \
	--docker-username="${MSC_EMAIL}" \
	--docker-password="${MLIS_LICENSE_KEY}" ||
    (echo "Failed to create secret!" 1>&2 && exit 1)
set -e -x


cat > config-domain.yaml << EOF
apiVersion: v1
data:
  $PUBLIC_DNS: ""
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: knative-serving
    app.kubernetes.io/version: 1.14.1
  name: config-domain
  namespace: knative-serving
EOF

# install mlis
sudo microk8s helm3 upgrade -i mlis aioli/ -n "${MLIS_NAMESPACE}" -f mlis-values.yaml

# set the external domain for knative/mlis
sudo microk8s kubectl apply -f config-domain.yaml

# install open-webui
sudo microk8s helm3 upgrade -i open-webui open-webui/open-webui -n open-webui --create-namespace --set ollama.enabled=false --set pipelines.enabled=false --set service.type=NodePort

# patch for knative serving garbage collection for MLIS

sudo microk8s kubectl patch cm  -n knative-serving config-gc  --type=strategic \
      -p '{"data":{"min-non-active-revisions":"0", "max-non-active-revisions": "0", "retain-since-create-time": "disabled","retain-since-last-active-time": "disabled"}}'

MLIS_PORT=$(kubectl get svc -n mlis aioli-master-service-mlis -o jsonpath='{.spec.ports[?(@.nodePort)].nodePort}')
set +x
echo "All software is installed. If you wish to stop here, you can."
echo "you can reach the UI of MLIS at http://${PUBLIC_DNS}:${MLIS_PORT}"
echo "If you want to install the rag pipelines and starter models, run the next script setup_4.sh"
echo "Before that you'll need to export the HF_TOKEN environment variable with your Hugging Face API token."
echo "check the notes in setup_5.sh, you may need to adjust the configuration for different GPU types"
echo "you can now run setup_5.sh"
