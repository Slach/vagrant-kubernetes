#!/usr/bin/env bash
set -exuv -o pipefail

if [[ -f ../versions.sh ]]; then
    source ../versions.sh
else
    VERSIONS_FILE=$(find /vagrant/ -name versions.sh)
    source ${VERSIONS_FILE}
fi
export DEBIAN_FRONTEND=noninteractive

swapoff -a
apt-get -y update
apt-get -y upgrade
apt-get install -y apt-transport-https ntp

#CPU performance governor
if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
    systemctl disable ondemand
    apt-get install -y cpufrequtils
    echo 'GOVERNOR="performance"' | tee /etc/default/cpufrequtils
    cpufreq-set --governor performance
fi

# docker
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7EA0A9C3F273FCD8
echo "deb https://download.docker.com/linux/ubuntu bionic edge" > /etc/apt/sources.list.d/docker.list
# cri-o
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 018BA5AD9DF57A4448F0E6CF8BECF1637AD8C79D
echo "deb http://ppa.launchpad.net/projectatomic/ppa/ubuntu bionic main" > /etc/apt/sources.list.d/crio.list
# kubernetes
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
# yq
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 9A2D61F6BB03CED7522B8E7D6657DBE0CC86BB64
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

# k9s
curl -sL -o /usr/local/bin/k9s_${K9S_VERSION}_Linux_x86_64.tar.gz https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_${K9S_VERSION}_Linux_x86_64.tar.gz
curl -sL https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/checksums.txt | grep Linux_x86_64.tar.gz > /usr/local/bin/k9s.sha256
sed -i "s/k9s_${K9S_VERSION}_Linux_x86_64.tar.gz/\/usr\/local\/bin\/k9s_${K9S_VERSION}_Linux_x86_64.tar.gz/g" /usr/local/bin/k9s.sha256
sha256sum -c /usr/local/bin/k9s.sha256
tar --verbose -zxvf /usr/local/bin/k9s_${K9S_VERSION}_Linux_x86_64.tar.gz -C /usr/local/bin k9s


apt-get install -y ipvsadm
modprobe ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh
modprobe overlay br_netfilter
# Setup required sysctl params, these persist across reboots.
cat > /etc/sysctl.d/99-kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

if [[ "${USE_CRI}" == "crio" ]]; then
    apt-get install -y cri-o-${CRIO_VERSION}=${CRIO_VERSION}*
elif [[ "${USE_CRI}" == "containerd" ]]; then
    apt-get install -y containerd.io=${CONTAINERD_VERSION}*
elif [[ "${USE_CRI}" == "docker" ]]; then
    apt-get install -y --no-install-recommends python-pip
    apt-get install -y docker-ce
    python -m pip install -U pip
    pip install -U setuptools
    pip2 install -U docker-compose
fi

systemctl stop docker  || true
systemctl stop containerd || true
systemctl stop crio || true
systemctl disable crio || true
systemctl disable docker || true
systemctl disable containerd || true

if [[ "${USE_CRI}" == "crio" ]]; then
        systemctl enable crio
elif [[ "${USE_CRI}" == "containerd" ]]; then
    systemctl enable containerd
elif [[ "${USE_CRI}" == "docker" ]]; then
    systemctl enable docker
fi

apt-get install -y kubelet=${K8S_VERSION}* kubeadm=${K8S_VERSION}* kubectl=${K8S_VERSION}* kubernetes-cni


apt-get install -y bash-completion
kubectl completion bash > /etc/bash_completion.d/kubectl

systemctl enable kubelet

if [[ "${LOCAL_ETCD}" == "False" ]]; then
    systemctl disable etcd || true
else
    apt-get install -y etcd
    systemctl enable etcd
fi

if [[ "${USE_CRI}" == "crio" ]]; then
cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///var/run/crio/crio.sock
image-endpoint: unix:///var/run/crio/crio.sock
timeout: 10
debug: false
EOF

    # https://github.com/kubernetes/kubeadm/issues/874, cgroup-driver=systemd DEPRECATED
    echo "KUBELET_EXTRA_ARGS=--cgroup-driver=systemd --container-runtime-endpoint=unix:///var/run/crio/crio.sock --image-pull-progress-deadline=10m --image-service-endpoint=unix:///var/run/crio/crio.sock" > /etc/default/kubelet
    # TODO add my private registries
    sed -i -e '/^#registries = \[$/,/^#\]$/s/^#//g' /etc/crio/crio.conf
    systemctl restart crio
    kubeadm config images pull -v 2 --cri-socket=/var/run/crio/crio.sock
    crictl pull docker.io/cloudnativelabs/kube-router:latest
    crictl pull docker.io/aquasec/kube-bench:latest
elif [[ "${USE_CRI}" == "containerd" ]]; then
cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

    echo "KUBELET_EXTRA_ARGS=--container-runtime-endpoint=unix:///run/containerd/containerd.sock --image-pull-progress-deadline=10m" > /etc/default/kubelet
    containerd config default > /etc/containerd/config.toml
    systemctl restart containerd
    kubeadm config images pull -v 2 --cri-socket=/run/containerd/containerd.sock
    crictl images pull docker.io/cloudnativelabs/kube-router:latest
    crictl images pull docker.io/aquasec/kube-bench:latest
elif [[ "${USE_CRI}" == "docker" ]]; then
    echo "KUBELET_EXTRA_ARGS=--image-pull-progress-deadline=10m" > /etc/default/kubelet
    systemctl restart docker
    kubeadm config images pull -v 2
    docker pull docker.io/cloudnativelabs/kube-router:latest
    docker pull docker.io/aquasec/kube-bench:latest
fi