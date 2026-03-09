#!/bin/bash
# Attack Path Lab - Complete Setup Script
# This script automates the entire lab deployment process

set -e

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$LAB_DIR"

echo "================================================"
echo "    Attack Path Lab - Automated Setup"
echo "================================================"
echo ""
echo "This script will:"
echo "1. Check prerequisites (VirtualBox, Vagrant)"
echo "2. Install required Vagrant plugins"
echo "3. Download Vagrant boxes (may take 2-3 hours)"
echo "4. Start and provision all virtual machines"
echo "5. Configure the lab environment"
echo ""
echo "NOTE: Ensure you have at least 16 GB RAM and 50 GB free disk space."
echo "================================================"

read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 1
fi

# Check prerequisites
echo ""
echo "=== Checking Prerequisites ==="

# Check VirtualBox
if ! command -v VBoxManage &> /dev/null; then
    echo "❌ VirtualBox not found. Please install VirtualBox 6.0 or later."
    echo "   Download from: https://www.virtualbox.org/wiki/Downloads"
    exit 1
else
    VBOX_VERSION=$(VBoxManage --version | cut -d_ -f1)
    echo "✓ VirtualBox version $VBOX_VERSION detected"
fi

# Check Vagrant
if ! command -v vagrant &> /dev/null; then
    echo "❌ Vagrant not found. Please install Vagrant 2.2 or later."
    echo "   Download from: https://www.vagrantup.com/downloads"
    exit 1
else
    VAGRANT_VERSION=$(vagrant --version | cut -d' ' -f2)
    echo "✓ Vagrant version $VAGRANT_VERSION detected"
fi

# Check RAM (approximate)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    TOTAL_RAM=$(free -g | awk '/^Mem:/ {print $2}')
    if [[ $TOTAL_RAM -lt 12 ]]; then
        echo "⚠️  Warning: Only $TOTAL_RAM GB RAM detected. Minimum 12 GB recommended."
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo "✓ $TOTAL_RAM GB RAM available"
    fi
fi

# Install Vagrant plugins
echo ""
echo "=== Installing Vagrant Plugins ==="

PLUGINS=("vagrant-windows" "vagrant-reload")
for plugin in "${PLUGINS[@]}"; do
    if vagrant plugin list | grep -q "$plugin"; then
        echo "✓ Plugin '$plugin' already installed"
    else
        echo "Installing '$plugin'..."
        vagrant plugin install "$plugin"
    fi
done

# Generate flags
echo ""
echo "=== Generating Challenge Flags ==="
if [[ -f "./flags/generate.py" ]]; then
    echo "Generating random flags for all challenges..."
    python3 ./flags/generate.py
    echo "Flags generated successfully."
else
    echo "⚠️  Flag generator not found. Using default flags."
fi

# Download boxes (optional - will happen automatically during vagrant up)
echo ""
echo "=== Downloading Vagrant Boxes ==="
echo "Note: This may take 2-3 hours depending on your internet connection."
echo "Windows boxes are large (several GB each)."
echo ""
read -p "Start downloading boxes now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Downloading Kali Linux box..."
    vagrant box add kalilinux/rolling --provider virtualbox --no-provision || true
    
    echo "Downloading Windows Server 2019 box..."
    vagrant box add mwrock/Windows2019 --provider virtualbox --no-provision || true
    
    echo "Downloading Windows 10 box..."
    vagrant box add mwrock/Windows10 --provider virtualbox --no-provision || true
    
    echo "Box download completed (or already present)."
else
    echo "Skipping box download. Boxes will be downloaded during 'vagrant up'."
fi

# Start VMs in correct order
echo ""
echo "=== Starting Virtual Machines ==="
echo "Starting VMs in recommended order..."
echo "This will take a while. You may see timeouts - this is normal for Windows VMs."

# Start DC01 first (domain controller)
echo ""
echo "1. Starting DC01 (Domain Controller)..."
vagrant up dc01 --no-provision || {
    echo "⚠️  DC01 may have rebooted. This is normal for domain controller setup."
}

# Wait for DC01 to be reachable
echo "Waiting for DC01 to stabilize..."
sleep 30

# Start WEB02 (needs domain controller for domain join)
echo ""
echo "2. Starting WEB02 (Web Server)..."
vagrant up web02 --no-provision || {
    echo "⚠️  WEB02 may have rebooted during domain join."
}

# Start other internal machines
echo ""
echo "3. Starting remaining internal machines..."
for vm in files02 client02 dev04 prod01; do
    echo "   Starting $vm..."
    vagrant up $vm --no-provision || {
        echo "⚠️  $vm may have rebooted during domain join."
    }
done

# Start Kali last
echo ""
echo "4. Starting Kali Linux (Attacker)..."
vagrant up kali --no-provision

# Provision all VMs
echo ""
echo "=== Provisioning Virtual Machines ==="
echo "Running provisioning scripts to configure vulnerabilities and flags..."

# Run provisioning script
if [[ -f "./scripts/provision-all.sh" ]]; then
    ./scripts/provision-all.sh
else
    echo "Running individual provisioning..."
    vagrant provision dc01
    sleep 10
    vagrant provision web02
    vagrant provision files02
    vagrant provision client02
    vagrant provision dev04
    vagrant provision prod01
    vagrant provision kali
fi

echo ""
echo "================================================"
echo "    Lab Setup Complete!"
echo "================================================"
echo ""
echo "Access the lab using the following methods:"
echo ""
echo "1. Web Frontend (Challenge Portal):"
echo "   http://10.0.1.10:8080"
echo ""
echo "2. Kali Linux (Attacker Machine):"
echo "   SSH:    vagrant ssh kali"
echo "   IP:     10.0.1.10"
echo ""
echo "3. Windows Machines:"
echo "   Use RDP or WinRM with the credentials below."
echo "   You can also use 'vagrant rdp <vmname>' if vagrant-rdp plugin is installed."
echo ""
echo "4. Network:"
echo "   Public:    10.0.1.0/24"
echo "   Internal:  10.0.2.0/24"
echo "   Domain:    lab.local"
echo ""
echo "For troubleshooting, see docs/SETUP.md"
echo "================================================"