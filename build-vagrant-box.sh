#!/usr/bin/env bash
set -exuv -o pipefail
export USE_CRI=${USE_CRI:-containderd}
export RELEASE_DATE=${RELEASE_DATE:-$(date +%Y%m%d%H%M%S)}
export K8S_VERSION=${K8S_VERSION:-1.15.1}
export VAGRANT_CLOUD_BOX=Slach/kubernetes-${USE_CRI}
export VAGRANT_CLOUD_VERSION=${VAGRANT_CLOUD_VERSION:-${K8S_VERSION}-${RELEASE_DATE}}

vagrant box update
vagrant destroy -f
vagrant up --provision


TMPDIR=$(mktemp -d)
K8S_VAGRANT=${TMPDIR}/k8s-vagrant
if [[ "$OSTYPE" == cygwin* ]]; then
    K8S_VAGRANT=`cygpath -w -l ${K8S_VAGRANT}`
fi
rm -rfv "${K8S_VAGRANT}/*"

bash -x -c "K8S_VAGRANT='${K8S_VAGRANT}' ./scripts/vagrant/resize-vmdk.sh"

bash -c "SCRIPT=scripts/vagrant/repartition.sh vagrant reload --provision"
bash -c "SCRIPT=scripts/vagrant/reset-ssh-keys.sh vagrant reload --provision"

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

    tar -I 'gzip -9' -cvf "${VBOX_FILE_CYGWIN}" -C "${VBOX_UNBOXED_CYGWIN}/" .
else
    tar -I 'gzip -9' -czf "${VBOX_FILE}" -C "${VBOX_UNBOXED}/" .
fi

vagrant cloud auth login
vagrant cloud publish ${VAGRANT_CLOUD_BOX} ${VAGRANT_CLOUD_VERSION} virtualbox ${VBOX_FILE} -f -d "Ubuntu/bionic64 with installed (but not configured) kubernetes, kubeadm, cri-o, containerd, docker-ce, img, k9s" --release --short-description "Ubuntu/bionic64 with installed (but not configured) kubernetes, kubeadm, cri-o, containerd, docker-ce, img, k9s"
rm -rfv "${K8S_VAGRANT}"

vagrant box remove -f ${VAGRANT_CLOUD_BOX} --all || true
vagrant box add Slach/vagrant-kubernetes --force

rm -rf ${TMPDIR}