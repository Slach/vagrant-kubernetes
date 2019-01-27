#!/usr/bin/env bash

# Reset to vagrant insecure key
curl -s -o /home/vagrant/.ssh/authorized_keys https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub
systemctl poweroff