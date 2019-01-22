# vagrant-kubernetes
This box contains installed but not configured following components:
- Ubuntu bionic
- Kubernetes / Kubeadm latest stable version
- cri-o / docker
- etcd
- come other tools need for troubleshooting

Use following ```Vagrantfile```
```
Vagrant.configure("2") do |config|
  config.vm.box = "Slach/vagrant-kubernetes"
end
```

Deployment examples which usage this box look here: https://github.com/Slach/k8s-russian.video/Vagrantfile