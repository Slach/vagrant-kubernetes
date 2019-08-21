Vagrant.configure(2) do |config|
    config.vm.box = "ubuntu/bionic64"
    # Disabled VirtualBox Guest updates
    if Vagrant.has_plugin?("vagrant-vbguest")
        config.vbguest.auto_update = false
    end

    # Create a private network, which allows host-only access to the machine
    # using a specific IP.
    # This is the docker network
    # config.vm.network "private_network", ip: "10.10.0.2", auto_config: false

    config.vm.provider :virtualbox do |vb|
        # Change this matching the power of your machine
        vb.memory = 1024
        vb.cpus = 1

        # Set the vboxnet interface to promiscous mode so that the docker veth
        # interfaces are reachable
        vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
        # Otherwise we get really slow DNS lookup on OSX (Changed DNS inside the machine)
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
        vb.customize ["modifyvm", :id, "--nictype1", "virtio" ]
        vb.customize ["modifyvm", :id, "--nictype2", "virtio" ]
	vb.customize [ "modifyvm", :id, "--uartmode1", "file", File.join(Dir.pwd, "vagrant-kubernetes.log") ]
    end

    VERSIONS = {
        "USE_CRI" => ENV["USE_CRI"] || "docker",
        "K8S_VERSION" => ENV["K8S_VERSION"] || "1.15",
        "CRIO_VERSION" => ENV["CRIO_VERSION"] || "1.15",
        "CONTAINERD_VERSION" => ENV["CONTAINERD_VERSION"] || "1.2.7",
        "IMG_VERSION" => ENV["IMG_VERSION"] || "0.5.7",
        "LOCAL_ETCD" => ENV["LOCAL_ETCD"] || "False",
        "K9S_VERSION" => ENV["K9S_VERSION"] || "0.8.2",
    }
    # Enable provisioning with a shell script.
    if ENV['SCRIPT']
        config.vm.provision "shell", :privileged => true, path: ENV['SCRIPT']
    else
       config.vm.provision "shell", :privileged => true, path: "scripts/install-k8s.sh", env: VERSIONS
       config.vm.provision "shell", :privileged => true, path: "scripts/vagrant/box-clean.sh", env: VERSIONS
    end
end
