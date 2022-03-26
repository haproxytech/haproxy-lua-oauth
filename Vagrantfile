Vagrant.configure("2") do |config|

    # ------------------------------------------------
    # NOTE: Comment out OSes you don't want to create
    # ------------------------------------------------

    config.vm.define "ubuntu20" do |server|
        server.vm.box = "ubuntu/focal64"
        server.vm.hostname = "ubuntu20"
        server.vm.network "private_network", ip: "192.168.56.30"
    end

    config.vm.define "centos8" do |server|
        server.vm.box = "centos/8"
        server.vm.hostname = "centos8"
        server.vm.network "private_network", ip: "192.168.56.39"
    end
end
