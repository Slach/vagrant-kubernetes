# vagrant-kubernetes
This box contains installed but not configured following components:
- Ubuntu bionic
- Kubernetes / Kubeadm latest stable version
- cri-o / docker / containerd
- etcd
- come other tools need for troubleshooting

Use following ```Vagrantfile``` for ```containerd``` (IMHO most useful CRI at current time)
```
Vagrant.configure("2") do |config|
  config.vm.box = "Slach/kubernetes-containerd"
end
```
you can use other CRI, just follow vagrant boxes from https://app.vagrantup.com/Slach/

Deployment examples which usage this box look here: https://github.com/Slach/k8s-russian.video/Vagrantfile