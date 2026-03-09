# Attack Path Lab - Setup and Deployment Guide

## Overview
This lab simulates a realistic Windows domain environment with multiple security misconfigurations leading from initial SQL injection to full domain compromise. The lab consists of 7 virtual machines across two isolated networks.

## Prerequisites

### Required Software
1. **VirtualBox** 6.0 or later
2. **Vagrant** 2.2.0 or later
3. **Vagrant Plugins**:
   ```bash
   vagrant plugin install vagrant-windows
   vagrant plugin install vagrant-reload
   ```
4. **Disk Space**: ~50 GB free space
5. **RAM**: Minimum 12 GB (recommended 16 GB)
6. **CPU**: 4+ cores with virtualization support

### Required Vagrant Boxes
The Vagrantfile uses the following boxes:
- `kalilinux/rolling` (Kali Linux)
- `mwrock/Windows2019` (Windows Server 2019)
- `mwrock/Windows10` (Windows 10)

These will be automatically downloaded on first run (may take time due to large Windows images).

## Quick Start

1. **Clone/Download** the lab to your local machine
2. **Navigate** to the lab directory:
   ```bash
   cd attack-lab
   ```
3. **Start the lab**:
   ```bash
   vagrant up
   ```
   This will download boxes and provision all VMs (may take 1-2 hours).

4. **Access the lab**:
   - Web frontend: http://10.0.1.10:8080
   - Kali SSH: `vagrant ssh kali`
   - Windows machines: Use RDP or WinRM with provided credentials

## Network Topology

### Public Network (10.0.1.0/24)
- **Kali Linux** (Attacker): 10.0.1.10
- **WEB02** (Public interface): 10.0.1.20

### Internal Network (10.0.2.0/24)
- **WEB02** (Internal interface): 10.0.2.20
- **DC01** (Domain Controller): 10.0.2.10
- **FILES02** (File Server): 10.0.2.30
- **CLIENT02** (Client Workstation): 10.0.2.40
- **DEV04** (Development Machine): 10.0.2.50
- **PROD01** (Production Server): 10.0.2.60

**Domain**: lab.local

## Credentials

### Domain Accounts
| Username | Password | Purpose |
|----------|----------|---------|
| Administrator | D@nAdm!n2024 | Domain Administrator |
| web_svc | WebSvc123! | Web service account |
| files_admin | FilesAdm!456 | File server admin (local admin on FILES02/CLIENT02) |
| dev_user | DevUser789! | Development user (has SeImpersonatePrivilege) |
| svc_kerb | KerbSvc!000 | Service account with SPN (Kerberoasting target) |

### Local Accounts
- **SQL Server**: sa password: SQLAdmin123! (if using mixed mode)
- **SQL Database**: webuser / WebDbPass!
- **Windows Local Administrator**: Password same as domain Administrator

## Challenge Flow

### Stage 1: SQL Injection → RCE
- Target: WEB02 (10.0.1.20)
- Vulnerability: SQL injection in login.aspx
- Goal: Execute commands via xp_cmdshell
- Flag: `C:\flags\stage1.txt`

### Stage 2: Privilege Escalation (WEB02)
- Target: WEB02
- Vulnerability: Unquoted service path
- Goal: Elevate to SYSTEM
- Flag: `C:\flags\stage2.txt`

### Stage 3: Lateral Movement (FILES02)
- Target: FILES02 (10.0.2.30)
- Method: Credentials found in `C:\Users\Public\creds.txt`
- Goal: Access file shares
- Flag: `\\FILES02\Data\flag.txt`

### Stage 4: Privilege Escalation (DEV04)
- Target: DEV04 (10.0.2.50)
- Vulnerability: SeImpersonatePrivilege → Potato attack
- Goal: Elevate to SYSTEM
- Flag: `C:\flags\stage4.txt`

### Stage 5: Kerberoasting
- Target: DC01 (10.0.2.10)
- Vulnerability: Service account with weak password
- Goal: Crack TGS ticket for svc_kerb
- Flag: `C:\flags\stage5.txt`

### Stage 6: DCSync Attack
- Target: DC01
- Vulnerability: DCSync permissions for svc_kerb
- Goal: Dump domain hashes
- Flag: `C:\flags\stage6.txt`

### Stage 7: Domain Admin Access
- Target: PROD01 (10.0.2.60)
- Method: Pass-the-hash with Administrator NTLM
- Goal: Access PROD01 as Domain Administrator
- Flag: `C:\Users\Administrator\Desktop\final.txt`

## Provisioning Notes

### Automatic Provisioning
The provisioning scripts will:
1. Install required Windows features (IIS, SQL Server, AD DS)
2. Configure vulnerabilities and misconfigurations
3. Join domain (requires reboot)
4. Create flag files

### Reboot Handling
Windows machines will reboot during domain join. Vagrant may lose connection. To complete provisioning:

1. After initial `vagrant up`, wait for all VMs to be created
2. Run provisioning again for Windows machines:
   ```bash
   vagrant provision web02
   vagrant provision dc01
   vagrant provision files02
   vagrant provision client02
   vagrant provision dev04
   vagrant provision prod01
   ```

Alternatively, use the provided helper script:
```bash
./scripts/provision-all.ps1  # Windows
./scripts/provision-all.sh   # Linux/Mac
```

### Manual Steps (if provisioning fails)
1. **SQL Server Installation**: WEB02 may require manual SQL Server Express installation if Chocolatey fails.
2. **Domain Join**: If domain join fails, check DNS settings (DC01 must be reachable).
3. **Firewall**: All firewalls are disabled for lab simplicity.

## Web Frontend

The lab includes a web-based challenge portal running on Kali (10.0.1.10:8080) with:

- Challenge descriptions and hints
- Flag validation API
- Progress tracking
- Network topology diagram

To start/restart the web frontend:
```bash
vagrant ssh kali
sudo systemctl start flag-api
```

## Useful Commands

### VM Management
```bash
# Start all VMs
vagrant up

# Start specific VM
vagrant up kali
vagrant up web02

# SSH/RDP access
vagrant ssh kali
vagrant rdp web02  # Requires vagrant-rdp plugin

# Check status
vagrant status

# Suspend/resume
vagrant suspend
vagrant resume

# Destroy and rebuild
vagrant destroy -f
vagrant up
```

### Lab Tools
Kali Linux comes pre-installed with:
- `nmap`, `sqlmap`, `metasploit`
- `impacket` scripts (secretsdump.py, GetUserSPNs.py)
- `crackmapexec`, `responder`
- `mimikatz` (Windows version in /opt)

## Troubleshooting

### Common Issues

1. **Vagrant timeout during provisioning**
   - Increase timeout in Vagrantfile: `config.vm.boot_timeout = 600`
   - Ensure host has sufficient RAM/CPU

2. **Windows boxes fail to download**
   - Manual download: `vagrant box add mwrock/Windows2019`
   - Use alternate box: Edit Vagrantfile to use `gusztavvargadr/windows-server-2019-standard`

3. **Domain join fails**
   - Verify DC01 is running: `vagrant status dc01`
   - Check IP connectivity: `vagrant ssh kali; ping 10.0.2.10`
   - Manual join: Log into VM with vagrant/vagrant credentials and join domain manually

4. **SQL Server not accessible**
   - Check service is running: `Get-Service MSSQLSERVER` on WEB02
   - Enable xp_cmdshell manually if needed

5. **Web frontend not accessible**
   - Check API service: `sudo systemctl status flag-api` on Kali
   - Ensure port 8080 is open: `sudo netstat -tlnp`

## Reset and Cleanup

To reset the lab to initial state:
```bash
# Destroy all VMs
vagrant destroy -f

# Remove downloaded boxes (optional)
vagrant box remove mwrock/Windows2019
vagrant box remove mwrock/Windows10
vagrant box remove kalilinux/rolling

# Start fresh
vagrant up
```

## Security Warning

This lab contains intentionally vulnerable systems. Do NOT expose these VMs to the internet or untrusted networks. Use only in isolated environments.

## Support

For issues, questions, or contributions:
- Check the troubleshooting section above
- Review Vagrant and VirtualBox logs
- Ensure all prerequisites are met

## License and Attribution

This lab is for educational purposes only. Use responsibly.

---
**Happy Hacking!**