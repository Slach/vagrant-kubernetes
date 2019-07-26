#!/usr/bin/env bash
set -exuv -o pipefail

declare -a ALL_CRI=("crio" "containerd" "docker")
for USE_CRI in "${ALL_CRI[@]}"
do
    export RELEASE_DATE=${RELEASE_DATE:-$(date +%Y%m%d%H%M%S)}
    export USE_CRI=${USE_CRI}
    export RELEASE_DATE=${RELEASE_DATE}
    export K8S_VERSION=${K8S_VERSION:-1.15.1}
    export CRIO_VERSION=${CRIO_VERSION:-1.14}
    export CONTAINERD_VERSION=${CONTAINERD_VERSION:-1.2.6}
    export IMG_VERSION=${IMG_VERSION:-0.5.7}
    export LOCAL_ETCD=${LOCAL_ETCD:-False}
    export K9S_VERSION=${K9S_VERSION:-0.7.13}
    bash -x build-vagrant-box.sh
done