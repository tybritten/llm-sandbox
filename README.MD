## LLM Sandbox


Prerequisites:
* Ubuntu 22 installed on node with GPU and at least 200GB of storage
* Access to the Internet
* this repo cloned
* a huggingface token with read access to the models you want (bge-large-en-v1.5, Meta-Llama-3-8B-Instruct)
* a mldm license key
* For MLIS:
  * the mlis/aioli helm chart downloaded and a docker token that can access the repos
  * OR
  * HPE MSC email, product SKU, and license key

  
#### Steps

run `setup_1.sh`, it will install the drivers and base stuff and reboot
then you log back in and run `setup_2.sh`
once it's done it'll tell you what you need to do next (export some of those values like keys and tokens) before running it
do that and run `setup_3.sh` and then depending on which apporach (MSC or downloaded chart) you'll run `setup_4.sh` or `setup_4_docker.sh`.
Once those are complete, done with a fully running environment.

there's more instructions before setup_5.sh which will deploy the pipelines and models

in the scripts I use <publicip>.nip.io for a PUBLIC_DNS var, you'll want to edit that for internal dns usage. And whatever dns should be wildcard. so *.myhostname.mydomain.net for MLIS to function properly

Available:
* http://<PUBLIC_DNS>:30080 - MLDM
* http://<PUBLIC_DNS>:30081 - OpenWebUI
* http://<PUBLIC_DNS>:<PORT>> - MLIS (you'll need to check the nodeport in use with `kubectl get svc -n mlis aioli-master-service-mlis -o jsonpath='{.spec.ports[?(@.nodePort)].nodePort}'`)


You can add models to openweb ui using the internal dns names (`http://<deploymentname>.mlis.svc.cluster.local/`)
