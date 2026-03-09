# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Global configuration
  config.vm.box_check_update = false
  config.vm.boot_timeout = 600
  config.vm.communicator = "winrm"
  
  # Configure WinRM for Windows boxes
  config.vm.provider "virtualbox" do |vb|
    vb.gui = true
    vb.memory = 2048
    vb.cpus = 2
  end
  
  # Kali Linux - Attacker machine
  config.vm.define "kali" do |kali|
    kali.vm.box = "kalilinux/rolling"
    kali.vm.hostname = "kali"
    kali.vm.network "private_network", ip: "10.0.1.10", netmask: "24", virtualbox__intnet: "public"
    kali.vm.provider "virtualbox" do |vb|
      vb.name = "attack-lab-kali"
      vb.memory = 2048
      vb.cpus = 2
      vb.gui = false
    end
    kali.vm.provision "shell", path: "provisioning/kali.sh"
  end

  # WEB02 - Public web server (dual-homed)
  config.vm.define "web02" do |web|
    web.vm.box = "mwrock/Windows2019"
    web.vm.hostname = "WEB02"
    # Public network interface
    web.vm.network "private_network", ip: "10.0.1.20", netmask: "24", virtualbox__intnet: "public"
    # Internal network interface
    web.vm.network "private_network", ip: "10.0.2.20", netmask: "24", virtualbox__intnet: "internal"
    web.vm.provider "virtualbox" do |vb|
      vb.name = "attack-lab-web02"
      vb.memory = 4096
      vb.cpus = 2
      vb.gui = true
    end
    web.vm.provision "shell", path: "provisioning/web02.ps1", privileged: true
    web.vm.synced_folder ".", "/vagrant", disabled: true
  end

  # DC01 - Domain Controller
  config.vm.define "dc01" do |dc|
    dc.vm.box = "mwrock/Windows2019"
    dc.vm.hostname = "DC01"
    dc.vm.network "private_network", ip: "10.0.2.10", netmask: "24", virtualbox__intnet: "internal"
    dc.vm.provider "virtualbox" do |vb|
      vb.name = "attack-lab-dc01"
      vb.memory = 4096
      vb.cpus = 2
      vb.gui = true
    end
    dc.vm.provision "shell", path: "provisioning/dc01.ps1", privileged: true
    dc.vm.synced_folder ".", "/vagrant", disabled: true
  end

  # FILES02 - File Server
  config.vm.define "files02" do |files|
    files.vm.box = "mwrock/Windows2019"
    files.vm.hostname = "FILES02"
    files.vm.network "private_network", ip: "10.0.2.30", netmask: "24", virtualbox__intnet: "internal"
    files.vm.provider "virtualbox" do |vb|
      vb.name = "attack-lab-files02"
      vb.memory = 2048
      vb.cpus = 2
      vb.gui = true
    end
    files.vm.provision "shell", path: "provisioning/files02.ps1", privileged: true
    files.vm.synced_folder ".", "/vagrant", disabled: true
  end

  # CLIENT02 - Client workstation
  config.vm.define "client02" do |client|
    client.vm.box = "mwrock/Windows10"
    client.vm.hostname = "CLIENT02"
    client.vm.network "private_network", ip: "10.0.2.40", netmask: "24", virtualbox__intnet: "internal"
    client.vm.provider "virtualbox" do |vb|
      vb.name = "attack-lab-client02"
      vb.memory = 2048
      vb.cpus = 2
      vb.gui = true
    end
    client.vm.provision "shell", path: "provisioning/client02.ps1", privileged: true
    client.vm.synced_folder ".", "/vagrant", disabled: true
  end

  # DEV04 - Development machine
  config.vm.define "dev04" do |dev|
    dev.vm.box = "mwrock/Windows10"
    dev.vm.hostname = "DEV04"
    dev.vm.network "private_network", ip: "10.0.2.50", netmask: "24", virtualbox__intnet: "internal"
    dev.vm.provider "virtualbox" do |vb|
      vb.name = "attack-lab-dev04"
      vb.memory = 2048
      vb.cpus = 2
      vb.gui = true
    end
    dev.vm.provision "shell", path: "provisioning/dev04.ps1", privileged: true
    dev.vm.synced_folder ".", "/vagrant", disabled: true
  end

  # PROD01 - Production server
  config.vm.define "prod01" do |prod|
    prod.vm.box = "mwrock/Windows2019"
    prod.vm.hostname = "PROD01"
    prod.vm.network "private_network", ip: "10.0.2.60", netmask: "24", virtualbox__intnet: "internal"
    prod.vm.provider "virtualbox" do |vb|
      vb.name = "attack-lab-prod01"
      vb.memory = 2048
      vb.cpus = 2
      vb.gui = true
    end
    prod.vm.provision "shell", path: "provisioning/prod01.ps1", privileged: true
    prod.vm.synced_folder ".", "/vagrant", disabled: true
  end

  # Plugin requirements
  config.vagrant.plugins = ["vagrant-windows", "vagrant-reload"]
end