#!/usr/bin/env bash
set -exuv -o pipefail

# @TODO  
# declare -a ALL_CRI=("containerd" "crio" "docker")
declare -a ALL_CRI=("containerd" "docker")
for USE_CRI in "${ALL_CRI[@]}"
do
    export RELEASE_DATE=${RELEASE_DATE:-$(date +%Y%m%d%H%M%S)}
    source ./versions.sh
    source ./build-vagrant-box.sh
done