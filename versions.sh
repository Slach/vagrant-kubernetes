#!/usr/bin/env bash
export USE_CRI=${USE_CRI:-docker} # avaiable varants "docker", "crio", "containerd"
export K8S_VERSION=${K8S_VERSION:-1.15}
export CRIO_VERSION=${CRIO_VERSION:-1.15}
export CONTAINERD_VERSION=${CONTAINERD_VERSION:-1.2.6}
export IMG_VERSION=${IMG_VERSION:-0.5.7}
export LOCAL_ETCD=${LOCAL_ETCD:-False}
export K9S_VERSION=${K9S_VERSION:-0.8.0}
