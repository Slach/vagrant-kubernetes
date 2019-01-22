#!/usr/bin/env bash
set -exuv -o pipefail

vagrant destroy -f
vagrant up --provision
vagrant halt
VAGRANT_CLOUD_BOX=Slach/vagrant-kubernetes
VERSION=1.13.2
TMPDIR=$(mktemp -d)
K8S_VAGRANT=${TMPDIR}/k8s-vagrant
if [[ "$OSTYPE" == cygwin* ]]; then
    K8S_VAGRANT=`cygpath -w -l ${K8S_VAGRANT}`
fi
rm -fv "${K8S_VAGRANT}/package.box"
vagrant package --output "${K8S_VAGRANT}/package.box" --vagrantfile Vagrantfile.dist

VBOX_UNBOXED=${K8S_VAGRANT}/unboxed
mkdir -p -v "${VBOX_UNBOXED}"

VBOX_FILE=${K8S_VAGRANT}/package.box
if [[ "$OSTYPE" == cygwin* ]]; then
    VBOX_FILE_CYGWIN=`cygpath -u ${VBOX_FILE}`
    VBOX_UNBOXED_CYGWIN=`cygpath -u ${VBOX_UNBOXED}`
    tar xzf "${VBOX_FILE_CYGWIN}" -C "${VBOX_UNBOXED_CYGWIN}/"
else
    tar xzf "${K8S_VAGRANT}/package.box" -C "${VBOX_UNBOXED}/"
fi 

sed -i.back '/vagrant_private_key/d' "${VBOX_UNBOXED}/Vagrantfile"
rm -fv "${VBOX_UNBOXED}/Vagrantfile.back"
rm -fv "${VBOX_UNBOXED}/vagrant_private_key"

VBOX_FILE=${K8S_VAGRANT}/stripped.box
if [[ "$OSTYPE" == cygwin* ]]; then
    VBOX_FILE_CYGWIN=`cygpath -u ${VBOX_FILE}`
    VBOX_UNBOXED_CYGWIN=`cygpath -u ${VBOX_UNBOXED}`
    GZIP=-9 tar -czf "${VBOX_FILE_CYGWIN}" -C "${VBOX_UNBOXED_CYGWIN}/" .
else
    GZIP=-9 tar -czf "${VBOX_FILE}" -C "${VBOX_UNBOXED}/" .
fi

vagrant cloud auth login
vagrant cloud publish ${VAGRANT_CLOUD_BOX} ${VERSION} virtualbox ${VBOX_FILE} -f -d "Ubuntu bionic64 vagrant with installed (but not configured) kubernetes, etcd, cri-o" --release --short-description "Download and use AS IS Without any Warranty!"
rm -rfv "${K8S_VAGRANT}"

vagrant box remove -f Slach/vagrant-kubernetes || true
vagrant box add Slach/vagrant-kubernetes
