#!/usr/bin/env bash
export USE_CRI=${USE_CRI:-docker} # avaiable varants "docker", "crio", "containerd"
export K8S_VERSION=${K8S_VERSION:-1.18.1}
export CRIO_VERSION=${CRIO_VERSION:-1.17}
export CONTAINERD_VERSION=${CONTAINERD_VERSION:-1.3.3}