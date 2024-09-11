#!/bin/bash
if [[ -z "${HF_TOKEN}" ]]; then
  echo "HF_TOKEN is undefined"
  exit 1
fi

set -e
set -x

export PUBLIC_DNS=$(curl -s http://icanhazip.com).nip.io

AIOLI_CHART=$(sudo microk8s helm3 ls -A --filter mlis --output json | jq -r '.[0].chart')

source venv/bin/activate
pip install aioli-sdk==${AIOLI_CHART:6}

export AIOLI_CONTROLLER=http://localhost:$(kubectl get svc -n mlis aioli-master-service-mlis -o jsonpath='{.spec.ports[?(@.nodePort)].nodePort}')
export AIOLI_USER=admin
export AIOLI_PASS=HPE2024Password

aioli r create huggingface --type openllm --secret-key $HF_TOKEN

aioli m create Meta-Llama-3.1-8B-Instruct --format custom --image "vllm/vllm-openai:latest" \
  --requests-gpu 1 --limits-gpu 1 --limits-memory 30Gi -e HUGGING_FACE_HUB_TOKEN=$HF_TOKEN -e AIOLI_DISABLE_LOGGER=true --arg=--model -a meta-llama/Meta-Llama-3.1-8B-Instruct --arg=--port -a 8080


# create embedding image. Please pick the right image based on your GPU type:
# https://github.com/huggingface/text-embeddings-inference?tab=readme-ov-file#docker-images
T4_IMAGE="ghcr.io/huggingface/text-embeddings-inference:turing-1.5"
A100_IMAGE="ghcr.io/huggingface/text-embeddings-inference:1.5"
H100_IMAGE="ghcr.io/huggingface/text-embeddings-inference:hopper-1.5"
L40S_IMAGE="ghcr.io/huggingface/text-embeddings-inference:89-1.5"
A4_IMAGE="ghcr.io/huggingface/text-embeddings-inference:86-1.5"
aioli m create bge-large-en-v1.5 --format custom --image "${A4_IMAGE}" \
  --requests-gpu 1 --limits-gpu 1 -e HF_API_TOKEN=$HF_TOKEN --arg=--model-id -a BAAI/bge-large-en-v1.5 --arg=--auto-truncate

aioli d create --model bge-large-en-v1.5 --namespace mlis embed  --autoscaling-min-replica 1 --autoscaling-max-replica 1
aioli d create --model Meta-Llama-3.1-8B-Instruct --namespace mlis llama3  --autoscaling-min-replica 1 --autoscaling-max-replica 1

PACH_VERSION=$(sudo microk8s helm3 ls -A --filter mldm --output json | jq -r '.[0].app_version')

curl -o /tmp/pachctl.deb -L https://github.com/pachyderm/pachyderm/releases/download/v${PACH_VERSION}/pachctl_${PACH_VERSION}_amd64.deb && sudo dpkg -i /tmp/pachctl.deb

pachctl connect http://localhost:30080

pachctl create repo documents

pachctl create pipeline --jsonnet https://raw.githubusercontent.com/tybritten/rag-pdf/main/pipelines/templates/parse.jsonnet --arg input_repo=documents
pachctl create pipeline --jsonnet https://raw.githubusercontent.com/tybritten/rag-pdf/main/pipelines/templates/embed.jsonnet
pachctl create pipeline --jsonnet https://raw.githubusercontent.com/tybritten/rag-pdf/main/pipelines/templates/ui.jsonnet --arg mldm_base_url=http://$PUBLIC_DNS:30080
