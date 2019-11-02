#!/usr/bin/env bash
export USE_CRI=${USE_CRI:-docker} # avaiable varants "docker", "crio", "containerd"
export K8S_VERSION=${K8S_VERSION:-1.16.2}
export CRIO_VERSION=${CRIO_VERSION:-1.15}
export CONTAINERD_VERSION=${CONTAINERD_VERSION:-1.2.10}
export IMG_VERSION=${IMG_VERSION:-0.5.7}
export K9S_VERSION=${K9S_VERSION:-0.9.2}
