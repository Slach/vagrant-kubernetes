#!/usr/bin/env bash
set -exuv -o pipefail

K8S_VERSION=1.13
CRIO_VERSION=1.13
IMG_VERSION=0.5.6
USE_DOCKER=False
LOCAL_ETCD=False

export DEBIAN_FRONTEND=noninteractive

swapoff -a
apt-get -y update
apt-get -y upgrade
apt-get install -y apt-transport-https ntp

#CPU performance governor
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    systemctl disable ondemand
    apt-get install -y cpufrequtils
    echo 'GOVERNOR="performance"' | tee /etc/default/cpufrequtils
    cpufreq-set --governor performance
fi

# docker, cri-o, yq
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 8D81803C0EBFCD88 018BA5AD9DF57A4448F0E6CF8BECF1637AD8C79D 9A2D61F6BB03CED7522B8E7D6657DBE0CC86BB64

# docker
# apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 8D81803C0EBFCD88
echo "deb https://download.docker.com/linux/ubuntu bionic edge" > /etc/apt/sources.list.d/docker.list
# cri-o
# apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 018BA5AD9DF57A4448F0E6CF8BECF1637AD8C79D
echo "deb http://ppa.launchpad.net/projectatomic/ppa/ubuntu bionic main" > /etc/apt/sources.list.d/crio.list
# kubernetes
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
# yq
# apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 9A2D61F6BB03CED7522B8E7D6657DBE0CC86BB64
echo "deb http://ppa.launchpad.net/rmescandon/yq/ubuntu bionic main" > /etc/apt/sources.list.d/yq.list

apt-get update
apt-get purge -y snapd puppet* chef* cloud*
apt-get install -y jq yq ethtool mc htop

# rq for TOML parsing
# curl -sL https://github.com/dflemstr/rq/releases/download/v0.10.4/record-query-v0.10.4-x86_64-unknown-linux-gnu.tar.gz | tar --verbose -zxvf - --transform "flags=r;s|x86_64-unknown-linux-gnu/rq|rq|" -C /usr/local/bin x86_64-unknown-linux-gnu/rq

# img, TODO make .deb package?
curl -sL -o /usr/local/bin/img https://github.com/genuinetools/img/releases/download/v${IMG_VERSION}/img-linux-amd64
curl -sL -o /usr/local/bin/img.sha256 https://github.com/genuinetools/img/releases/download/v${IMG_VERSION}/img-linux-amd64.sha256
sed -i "s/\/home\/travis\/gopath\/src\/github.com\/genuinetools\/img\/cross\/img\-linux\-amd64/\/usr\/local\/bin\/img/g" /usr/local/bin/img.sha256
sha256sum -c /usr/local/bin/img.sha256

apt-get install -y ipvsadm
modprobe ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh
modprobe overlay br_netfilter
# Setup cri-o sysctl params, these persist across reboots.
cat > /etc/sysctl.d/99-kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

if [[ "${USE_DOCKER}" == "False" ]]; then
    apt-get install -y cri-o-${CRIO_VERSION}=${CRIO_VERSION}*
else
    apt-get install -y --no-install-recommends python-pip
    apt-get install -y docker-ce
    python -m pip install -U pip
    pip install -U setuptools
    pip2 install -U docker-compose
fi

apt-get install -y kubelet=${K8S_VERSION}* kubeadm=${K8S_VERSION}* kubectl=${K8S_VERSION}* kubernetes-cni


apt-get install -y bash-completion
kubectl completion bash > /etc/bash_completion.d/kubectl

systemctl enable kubelet
systemctl start kubelet

if [[ "${LOCAL_ETCD}" == "False" ]]; then
    systemctl disable etcd || true
else
    apt-get install -y etcd
    systemctl enable etcd
fi

if [[ "${USE_DOCKER}" == "False" ]]; then
    # https://github.com/kubernetes/kubeadm/issues/874, cgroup-driver=systemd DEPRECATED
    echo "KUBELET_EXTRA_ARGS=--cgroup-driver=systemd --container-runtime-endpoint=unix:///var/run/crio/crio.sock --image-pull-progress-deadline=10m --image-service-endpoint=unix:///var/run/crio/crio.sock" > /etc/default/kubelet
    # TODO add my private registries
    sed -i -e '/^#registries = \[$/,/^#\]$/s/^#//g' /etc/crio/crio.conf
    systemctl enable crio
    systemctl start crio
    kubeadm config images pull -v 2 --cri-socket=/var/run/crio/crio.sock
    crictl pull docker.io/cloudnativelabs/kube-router:latest
    crictl pull docker.io/aquasec/kube-bench:latest
else
    echo "KUBELET_EXTRA_ARGS=--image-pull-progress-deadline=10m" > /etc/default/kubelet
    systemctl enable docker
    systemctl start docker
    kubeadm config images pull -v 2
    docker pull docker.io/cloudnativelabs/kube-router:latest
    docker pull docker.io/aquasec/kube-bench:latest
fi


