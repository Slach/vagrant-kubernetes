#!/usr/bin/env bash
set -exuv -o pipefail

export RELEASE_DATE=${RELEASE_DATE:-$(date +%Y%m%d%H%M%S)}

ALL_CRI=${ALL_CRI:-"crio containerd docker"}
for USE_CRI in ${ALL_CRI[@]}
do
    source ./versions.sh
    source ./build-vagrant-box.sh
done