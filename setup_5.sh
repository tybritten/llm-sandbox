#!/bin/bash
if [[ -z "${HF_TOKEN}" ]]; then
  echo "HF_TOKEN is undefined"
  exit 1
fi
#!/bin/bash
if [[ -z "${STORAGE_CLASS}" ]]; then
  echo "STORAGE_CLASS is undefined"
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


cat > pvc-creator.yaml << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: llama-cache-pvc
  namespace: mlis
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: $STORAGE_CLASS
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: starcoder-cache-pvc
  namespace: mlis
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: $STORAGE_CLASS
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: embedding-cache-pvc
  namespace: mlis
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: $STORAGE_CLASS
EOF
kubectl apply -f pvc-creator.yaml

cat > model-downloader.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: download-models
  namespace: mlis
spec:
  template:
    spec:
      containers:
      - name: model-installer
        image: kserve/huggingfaceserver:latest
        command: ["/bin/sh", "-c"]
        args:
          - |

            huggingface-cli download meta-llama/Meta-Llama-3.1-8B-Instruct --token $HF_TOKEN --local-dir /mnt/llama/
            [ $? -eq 0 ] && echo "Model download complete" || echo "Model download failed"
            huggingface-cli download bigcode/starcoder2-15b --token $HF_TOKEN --local-dir /mnt/starcoder/
            [ $? -eq 0 ] && echo "Model download complete" || echo "Model download failed"
            huggingface-cli download BAAI/bge-large-en-v1.5 --token $HF_TOKEN --local-dir /mnt/bge/
            [ $? -eq 0 ] && echo "Model download complete" || echo "Model download failed"            
        env:
        - name: HF_TOKEN
          value: $HF_TOKEN
        volumeMounts:
        - name: llama-cache
          mountPath: /mnt/llama
        - name: starcoder-cache
          mountPath: /mnt/startcoder
        - name: embedding-cache
          mountPath: /mnt/bge
      restartPolicy: OnFailure
      volumes:
      - name: llama-cache
        persistentVolumeClaim:
          claimName: llama-cache-pvc
      - name: starcoder-cache
        persistentVolumeClaim:
          claimName: starcoder-cache-pvc
      - name: embedding-cache
        persistentVolumeClaim:
          claimName: embedding-cache-pvc
EOF
kubectl apply -f model-downloader.yaml

aioli m create Meta-Llama-3.1-8B-Instruct --format custom --image "vllm/vllm-openai:latest" \
  --requests-gpu 1 --limits-gpu 1 --limits-memory 30Gi -e AIOLI_DISABLE_LOGGER=true --arg=--model -a /mnt/model/ \
  --url pvc://llama-cache-pvc/?containerPath=/mnt/model/ --arg=--port -a 8080

aioli m create starcoder2-15b --format custom --image "vllm/vllm-openai:latest" \
  --requests-gpu 1 --limits-gpu 1 --limits-memory 30Gi -e AIOLI_DISABLE_LOGGER=true --arg=--model -a /mnt/model/ \
  --url pvc://starcoder-cache-pvc/?containerPath=/mnt/model/ --arg=--port -a 8080

# create embedding image. Please pick the right image based on your GPU type:
# https://github.com/huggingface/text-embeddings-inference?tab=readme-ov-file#docker-images
T4_IMAGE="ghcr.io/huggingface/text-embeddings-inference:turing-1.5"
A100_IMAGE="ghcr.io/huggingface/text-embeddings-inference:1.5"
H100_IMAGE="ghcr.io/huggingface/text-embeddings-inference:hopper-1.5"
L40S_IMAGE="ghcr.io/huggingface/text-embeddings-inference:89-1.5"
A4_IMAGE="ghcr.io/huggingface/text-embeddings-inference:86-1.5"
aioli m create bge-large-en-v1.5 --format custom --image "${A4_IMAGE}" --url pvc://embedding-cache-pvc/?containerPath=/mnt/model/  \
  --requests-gpu 1 --limits-gpu 1 --arg=--model-id -a /mnt/model --arg=--auto-truncate

aioli d create --model bge-large-en-v1.5 --namespace mlis embed  --autoscaling-min-replica 1 --autoscaling-max-replica 1
aioli d create --model Meta-Llama-3.1-8B-Instruct --namespace mlis llama3  --autoscaling-min-replica 1 --autoscaling-max-replica 1

PACH_VERSION=$(sudo microk8s helm3 ls -A --filter mldm --output json | jq -r '.[0].app_version')

curl -o /tmp/pachctl.deb -L https://github.com/pachyderm/pachyderm/releases/download/v${PACH_VERSION}/pachctl_${PACH_VERSION}_amd64.deb && sudo dpkg -i /tmp/pachctl.deb

pachctl connect http://localhost:30080

pachctl create repo documents

pachctl create pipeline --jsonnet https://raw.githubusercontent.com/tybritten/rag-pdf/main/pipelines/templates/parse.jsonnet --arg input_repo=documents
pachctl create pipeline --jsonnet https://raw.githubusercontent.com/tybritten/rag-pdf/main/pipelines/templates/embed.jsonnet
pachctl create pipeline --jsonnet https://raw.githubusercontent.com/tybritten/rag-pdf/main/pipelines/templates/ui.jsonnet --arg mldm_base_url=http://$PUBLIC_DNS:30080
