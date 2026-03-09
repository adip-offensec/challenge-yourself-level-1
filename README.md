# Attack Path Lab

[![GitHub](https://img.shields.io/badge/GitHub-Repository-blue)](https://github.com/adip-offensec/challenge-yourself-level-1)

A comprehensive Windows domain penetration testing lab simulating real-world attack chains from initial access to domain compromise.

**GitHub Repository:** https://github.com/adip-offensec/challenge-yourself-level-1

## Lab Overview

This lab provides a realistic enterprise environment with multiple security misconfigurations across 7 virtual machines. The attack path includes:

1. **SQL Injection** → Command execution on public web server
2. **Privilege Escalation** via unquoted service path
3. **Lateral Movement** using discovered credentials
4. **Token Impersonation** (Potato attack) on development machine
5. **Kerberoasting** service account with weak password
6. **DCSync Attack** to dump domain hashes
7. **Domain Admin Access** to production server

## Quick Start

### Prerequisites
- VirtualBox 6.0+
- Vagrant 2.2+
- 16 GB RAM (minimum), 50 GB free disk space
- Vagrant plugins: `vagrant-windows`, `vagrant-reload`

### Installation

#### Automated Setup (Recommended)
Run the automated setup script:
```bash
./scripts/setup-lab.sh
```
This will check prerequisites, install plugins, download boxes, and configure the entire lab.

#### Manual Installation
1. Clone/download this repository
2. Install required Vagrant plugins:
   ```bash
   vagrant plugin install vagrant-windows
   vagrant plugin install vagrant-reload
   ```
3. Start the lab:
   ```bash
   vagrant up
   ```
   *Note: First run will download large Windows boxes (2-3 hours)*

4. After initial provisioning, run complete provisioning:
   ```bash
   ./scripts/provision-all.sh  # Linux/Mac
   # or
   .\scripts\provision-all.ps1  # Windows PowerShell
   ```

5. Access the lab:
   - Web frontend: http://10.0.1.10:8080
   - Kali SSH: `vagrant ssh kali`
   - Windows RDP: Use credentials below

## Network Architecture

```
Public Network (10.0.1.0/24)
├── Kali Linux (10.0.1.10) - Attacker
└── WEB02 (10.0.1.20) - Public web server

Internal Network (10.0.2.0/24)
├── WEB02 (10.0.2.20) - Internal interface
├── DC01 (10.0.2.10) - Domain Controller
├── FILES02 (10.0.2.30) - File Server
├── CLIENT02 (10.0.2.40) - Client Workstation
├── DEV04 (10.0.2.50) - Development Machine
└── PROD01 (10.0.2.60) - Production Server
```

**Domain**: lab.local

## Credentials

### Domain Accounts
| Username | Password | Purpose |
|----------|----------|---------|
| Administrator | D@nAdm!n2024 | Domain Administrator |
| web_svc | WebSvc123! | Web service account |
| files_admin | FilesAdm!456 | File server admin |
| dev_user | DevUser789! | Development user |
| svc_kerb | KerbSvc!000 | Service account with SPN |

### Local Accounts
- SQL Server: sa / SQLAdmin123!
- Database: webuser / WebDbPass!
- Windows Local Admin: Administrator / D@nAdm!n2024

## Challenge Flags

Each stage has a flag located as follows:

| Stage | Challenge | Flag Location |
|-------|-----------|---------------|
| 1 | SQL Injection → RCE | `C:\flags\stage1.txt` |
| 2 | Privilege Escalation (WEB02) | `C:\flags\stage2.txt` |
| 3 | Lateral Movement (FILES02) | `\\FILES02\Data\flag.txt` |
| 4 | Privilege Escalation (DEV04) | `C:\flags\stage4.txt` |
| 5 | Kerberoasting | `C:\flags\stage5.txt` |
| 6 | DCSync Attack | `C:\flags\stage6.txt` |
| 7 | Domain Admin Access | `C:\Users\Administrator\Desktop\final.txt` |

## Web Frontend

The lab includes a web-based challenge portal with:
- Interactive challenge descriptions
- Flag validation
- Progressive hints
- Progress tracking

Access: http://10.0.1.10:8080

## Tools Included

Kali Linux comes pre-installed with:
- **Enumeration**: nmap, crackmapexec, enum4linux
- **Exploitation**: sqlmap, metasploit, impacket
- **Privilege Escalation**: mimikatz, JuicyPotato (on DEV04)
- **Password Attacks**: hashcat, john, responder
- **Post-Exploitation**: bloodhound-python, powercat

## Attack Path Walkthrough

1. **Initial Access**: Discover SQL injection on http://10.0.1.20/login.aspx
2. **Command Execution**: Use xp_cmdshell to execute commands as NETWORK SERVICE
3. **Privilege Escalation**: Exploit unquoted service path on WEB02 to gain SYSTEM
4. **Credential Discovery**: Find `C:\Users\Public\creds.txt` with files_admin credentials
5. **Lateral Movement**: Use credentials to access FILES02 and CLIENT02
6. **Internal Recon**: Discover DEV04 and access with dev_user credentials
7. **Token Impersonation**: Use JuicyPotato to escalate to SYSTEM on DEV04
8. **Kerberoasting**: Enumerate SPNs, request TGS for svc_kerb, crack hash
9. **DCSync**: Use svc_kerb credentials to perform DCSync and dump domain hashes
10. **Domain Compromise**: Use Administrator hash to access PROD01 and capture final flag

## Troubleshooting

### Common Issues
- **Vagrant timeout**: Increase `config.vm.boot_timeout` in Vagrantfile
- **Domain join fails**: Ensure DC01 is running and reachable (10.0.2.10)
- **SQL Server not installed**: WEB02 may require manual SQL Server Express installation
- **Web frontend not loading**: Check `sudo systemctl status flag-api` on Kali

### Reset Lab
```bash
vagrant destroy -f
vagrant up
```

## Security Warning

⚠️ **WARNING**: This lab contains intentionally vulnerable systems. Do NOT expose these VMs to the internet or untrusted networks. Use only in isolated environments for educational purposes.

## License

Educational Use Only - See LICENSE file for details.

## Support

For issues or questions:
1. Check the [docs/SETUP.md](docs/SETUP.md) file
2. Review Vagrant and VirtualBox logs
3. Ensure all prerequisites are met

---

**Happy Hacking!**