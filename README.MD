## LLM Sandbox


Prerequisites:
* Ubuntu 22 installed on node with GPU and at least 200GB of storage
* Access to the Internet
* the setup files in this repo in the user home directory on the server
* the mlis/aioli helm chart downloaded
* a huggingface token with read access to the models you want (bge-large-en-v1.5, Meta-Llama-3-8B-Instruct)
* a docker token with access to the MLIS images
* a mldm license key
  
#### Steps

run setup_1.sh, it will install the drivers and base stuff and reboot
then you log back in and run setup_2.sh
once it's done it'll tell you what you need to do next (export some of those values like keys and tokens) before running it
do that and run setup_3.sh and you're done with a fully running environment

there's more instructions before setup_4.sh which will deploy the pipelines and models

in the scripts I use <publicip>.nip.io for a PUBLIC_DNS var, you'll want to edit that for internal dns usage. And whatever dns should be wildcard. so *.myhostname.mydomain.net for MLIS to function properly

Available:
http://<PUBLIC_DNS>:30080 - MLDM
http://<PUBLIC_DNS>:30080 - MLIS
http://<PUBLIC_DNS>:30080 - OpenWebUI

You can add models to openweb ui using the internal dns names (http://<deploymentname>.mlis.svc.cluster.local/)
