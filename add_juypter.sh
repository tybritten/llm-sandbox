
#!/bin/bash

sudo microk8s helm3 repo add jupyterhub https://hub.jupyter.org/helm-chart/

cat << 'EOF' > juypter-values.yaml
proxy:
  service:
    type: NodePort
    nodePorts:
      http: 32180

singleuser:
  profileList:
    - display_name: "Minimal CPU-Only environment"
      description: "Just Python"
      default: true
    - display_name: "Pytorch Cuda Notebook"
      description: "Full Pytorch Cuda GPU-enabled Notebook"
      kubespawner_override:
        image: quay.io/jupyter/pytorch-notebook:cuda12-2024-09-30
      profile_options:
        gpu:
          display_name: "GPU count"
          choices:
            one:
              display_name: "1"
              default: true
              kubespawner_override:
                extra_resource_limits:
                  nvidia.com/gpu: "1"
            two:
              display_name: "2"
              kubespawner_override:
                extra_resource_limits:
                  nvidia.com/gpu: "2"

EOF

sudo microk8s helm3 upgrade --cleanup-on-fail --install jupyterhub jupyterhub/jupyterhub \
  --namespace juypter --create-namespace --values juypter-values.yaml

