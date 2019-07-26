#!/usr/bin/env bash
set -exuv -o pipefail

sed -i -e "/UseDNS no/s/^#//" /etc/ssh/sshd_config
sed -i -e "/GSSAPIAuthentication no/s/^#//" /etc/ssh/sshd_config

# Reset to vagrant insecure key
curl -s -o /home/vagrant/.ssh/authorized_keys https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub
systemctl poweroff