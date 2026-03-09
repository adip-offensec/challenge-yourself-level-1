#!/bin/bash

# Update and install essential tools
echo "[*] Updating package list..."
apt-get update -y

echo "[*] Installing penetration testing tools..."
apt-get install -y \
  nmap \
  sqlmap \
  crackmapexec \
  responder \
  seclists \
  dirb \
  gobuster \
  metasploit-framework \
  wireshark-qt \
  tcpdump \
  netcat-traditional \
  net-tools \
  curl \
  wget \
  git \
  python3 \
  python3-pip \
  python3-venv \
  openvpn \
  ssh \
  rdesktop \
  freerdp2-x11

echo "[*] Installing Python packages..."
pip3 install impacket \
  requests \
  flask \
  colorama \
  paramiko \
  pycryptodome \
  ldap3

echo "[*] Cloning useful repositories..."
cd /opt
git clone https://github.com/fortra/impacket.git --depth 1
cd impacket && pip3 install . && cd ..

git clone https://github.com/SecureAuthCorp/Responder.git --depth 1
git clone https://github.com/PowerShellMafia/PowerSploit.git --depth 1
git clone https://github.com/gentilkiwi/mimikatz.git --depth 1

echo "[*] Setting up web frontend..."
mkdir -p /var/www/attack-lab
cp -r /vagrant/web-frontend/* /var/www/attack-lab/
cp -r /vagrant/flags /var/www/attack-lab/
chmod -R 755 /var/www/attack-lab

echo "[*] Creating service for flag validation API..."
cat > /etc/systemd/system/flag-api.service << EOF
[Unit]
Description=Attack Lab Flag Validation API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/attack-lab/api
ExecStart=/usr/bin/python3 /var/www/attack-lab/api/validate.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable flag-api.service
systemctl start flag-api.service

echo "[*] Setting up firewall rules..."
ufw allow 22
ufw allow 80
ufw allow 8080
ufw --force enable

echo "[*] Creating aliases..."
echo "alias ll='ls -la'" >> /home/vagrant/.bashrc
echo "alias scan='nmap -sV -sC -oA scan'" >> /home/vagrant/.bashrc
echo "alias sqlmap='sqlmap --batch'" >> /home/vagrant/.bashrc

echo "[*] Provisioning completed!"
echo "[*] Kali IP: 10.0.1.10"
echo "[*] Web frontend available at http://10.0.1.10:8080"
echo "[*] To start the flag validation API: sudo systemctl start flag-api"