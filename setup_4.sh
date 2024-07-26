#!/bin/bash
if [[ -z "${HF_TOKEN}" ]]; then
  echo "HF_TOKEN is undefined"
  exit 1
fi

export PUBLIC_DNS=$(curl -s http://icanhazip.com).nip.io

source venv/bin/activate
pip install aioli-sdk

export AIOLI_CONTROLLER=http://localhost:$(kubectl get svc -n mlis aioli-master-service-mlis -o jsonpath='{.spec.ports[?(@.nodePort)].nodePort}')
export AIOLI_USER=admin
export AIOLI_PASS=HPE2024Password

aioli r create huggingface --type openllm --secret-key $HF_TOKEN

aioli m create Meta-Llama-3-8B-Instruct --format openllm --url openllm://meta-llama/Meta-Llama-3-8B \
  --registry huggingface --requests-gpu 1 --limits-gpu 1


# create embedding image. Please pick the right image based on your GPU type:
# https://github.com/huggingface/text-embeddings-inference?tab=readme-ov-file#docker-images
aioli m create bge-large-en-v1.5 --format custom --image ghcr.io/huggingface/text-embeddings-inference:1.5 \
  --requests-gpu 1 --limits-gpu 1 -e HF_API_TOKEN=$HF_TOKEN --arg=--model-id -a BAAI/bge-large-en-v1.5

aioli d create --model bge-large-en-v1.5 --namespace mlis embedding  --autoscaling-min-replica 1 --autoscaling-max-replica 1
aioli d create --model Meta-Llama-3-8B-Instruct --namespace mlis llama3  --autoscaling-min-replica 1 --autoscaling-max-replica 1

curl -o /tmp/pachctl.deb -L https://github.com/pachyderm/pachyderm/releases/download/v2.10.7/pachctl_2.10.7_amd64.deb && sudo dpkg -i /tmp/pachctl.deb

pachctl connect http://localhost:30080

pachctl create repo documents

pachctl create pipeline --jsonnet https://raw.githubusercontent.com/tybritten/rag-pdf/main/pipelines/templates/parse.jsonnet --arg input_repo=documents --arg mldm_base_url=http://$PUBLIC_DNS:30080
pachctl create pipeline --jsonnet https://raw.githubusercontent.com/tybritten/rag-pdf/main/pipelines/templates/embed.jsonnet --arg input_repo=documents --arg mldm_base_url=http://$PUBLIC_DNS:30080
pachctl create pipeline --jsonnet https://raw.githubusercontent.com/tybritten/rag-pdf/main/pipelines/templates/ui.jsonnet --arg input_repo=documents --arg mldm_base_url=http://$PUBLIC_DNS:30080
