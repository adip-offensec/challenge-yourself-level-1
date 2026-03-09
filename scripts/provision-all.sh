#!/bin/bash
# Provision all VMs in correct order

echo "=== Attack Path Lab Provisioning ==="
echo "This script will provision all VMs in recommended order."
echo "Note: Windows VMs may reboot during domain join."
echo ""

read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "1. Provisioning Kali Linux (attacker)..."
vagrant provision kali

echo ""
echo "2. Provisioning DC01 (domain controller)..."
vagrant provision dc01

echo ""
echo "Waiting for DC01 to stabilize..."
sleep 30

echo ""
echo "3. Provisioning WEB02 (web server)..."
vagrant provision web02

echo ""
echo "4. Provisioning FILES02 (file server)..."
vagrant provision files02

echo ""
echo "5. Provisioning CLIENT02 (client workstation)..."
vagrant provision client02

echo ""
echo "6. Provisioning DEV04 (development machine)..."
vagrant provision dev04

echo ""
echo "7. Provisioning PROD01 (production server)..."
vagrant provision prod01

echo ""
echo "=== Provisioning Complete ==="
echo "Web frontend: http://10.0.1.10:8080"
echo "Kali SSH: vagrant ssh kali"
echo ""
echo "If any VM failed, run 'vagrant provision <vmname>' individually."