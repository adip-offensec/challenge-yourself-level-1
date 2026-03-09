# DC01 Provisioning Script
# Sets up Domain Controller for lab.local with misconfigurations

Write-Host "[DC01] Starting provisioning..." -ForegroundColor Green

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force

# Install AD DS and DNS features
Write-Host "[DC01] Installing Active Directory Domain Services..." -ForegroundColor Yellow
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools

# Configure AD DS Forest
Write-Host "[DC01] Configuring forest lab.local..." -ForegroundColor Yellow
$safeModePassword = ConvertTo-SecureString "D5RmP@ssw0rd" -AsPlainText -Force
$domainServicesPassword = ConvertTo-SecureString "D@nAdm!n2024" -AsPlainText -Force

Install-ADDSForest `
    -DomainName "lab.local" `
    -DomainNetbiosName "LAB" `
    -ForestMode "WinThreshold" `
    -DomainMode "WinThreshold" `
    -SafeModeAdministratorPassword $safeModePassword `
    -InstallDns:$true `
    -NoRebootOnCompletion:$false `
    -Force:$true

# Script will continue after reboot via Vagrant
# We need to split script into two parts, but Vagrant will run script once.
# Instead, we'll configure after reboot using a scheduled task or check if domain already installed.
# Let's use a check: if domain already installed, skip forest installation.

# Actually Vagrant will run provision script after reboot if we use "reboot: true". 
# We'll keep simple: install forest and reboot. Vagrant will continue provisioning after reboot.
# We'll add a check.

# Check if domain controller already installed
if ((Get-WindowsFeature AD-Domain-Services).InstallState -eq "Installed") {
    Write-Host "[DC01] AD DS already installed, skipping forest promotion." -ForegroundColor Green
} else {
    Write-Host "[DC01] AD DS not installed, will reboot after forest promotion." -ForegroundColor Yellow
    exit 3010  # Exit code for reboot
}

# After reboot, continue here

Write-Host "[DC01] Creating domain users and groups..." -ForegroundColor Green

# Define users and passwords
$users = @(
    @{Name="web_svc"; Password="WebSvc123!"},
    @{Name="files_admin"; Password="FilesAdm!456"},
    @{Name="dev_user"; Password="DevUser789!"},
    @{Name="svc_kerb"; Password="KerbSvc!000"},
    @{Name="Administrator"; Password="D@nAdm!n2024"}
)

foreach ($user in $users) {
    $username = $user.Name
    $password = ConvertTo-SecureString $user.Password -AsPlainText -Force
    
    # Check if user exists
    try {
        Get-ADUser -Identity $username -ErrorAction Stop
        Write-Host "[DC01] User $username already exists." -ForegroundColor Gray
    } catch {
        New-ADUser -Name $username -SamAccountName $username -AccountPassword $password -Enabled $true -PasswordNeverExpires $true
        Write-Host "[DC01] Created user $username." -ForegroundColor Green
    }
}

# Create DCSyncers group and assign permissions
Write-Host "[DC01] Configuring DCSync permissions for svc_kerb..." -ForegroundColor Yellow
$dcsyncGroupName = "DCSyncers"
try {
    Get-ADGroup -Identity $dcsyncGroupName -ErrorAction Stop
    Write-Host "[DC01] Group $dcsyncGroupName already exists." -ForegroundColor Gray
} catch {
    New-ADGroup -Name $dcsyncGroupName -GroupScope Global -GroupCategory Security
    Write-Host "[DC01] Created group $dcsyncGroupName." -ForegroundColor Green
}

# Add svc_kerb to DCSyncers
Add-ADGroupMember -Identity $dcsyncGroupName -Members "svc_kerb"

# Grant DCSync rights using DSACLS (simplified approach)
# We'll use PowerShell to add extended rights
Write-Host "[DC01] Granting DCSync rights..." -ForegroundColor Yellow
$domainDN = (Get-ADDomain).DistinguishedName
$groupSID = (Get-ADGroup $dcsyncGroupName).SID.Value

# Using ADSI to set permissions (simplified)
$adsiPath = "LDAP://$domainDN"
$domainObj = [ADSI]$adsiPath
$secDescriptor = $domainObj.ObjectSecurity

# Define DCSync rights GUIDs
$dcSyncGuid1 = [Guid]("1131f6aa-9c07-11d1-f79f-00c04fc2dcd2")  # Replicating Directory Changes
$dcSyncGuid2 = [Guid]("1131f6ad-9c07-11d1-f79f-00c04fc2dcd2")  # Replicating Directory Changes All
$dcSyncGuid3 = [Guid]("89e95b76-444d-4c62-991a-0facbeda640c")  # Replicating Directory Changes In Filtered Set

# Create ACEs (simplified - using dsacls instead)
Write-Host "[DC01] Using dsacls to grant DCSync rights..." -ForegroundColor Yellow
$domainDNForDsacls = $domainDN
# Grant DCSync rights using dsacls
& dsacls `"$domainDNForDsacls`" /G `"LAB\$dcsyncGroupName:CA;Replicating Directory Changes`"
& dsacls `"$domainDNForDsacls`" /G `"LAB\$dcsyncGroupName:CA;Replicating Directory Changes All`"
& dsacls `"$domainDNForDsacls`" /G `"LAB\$dcsyncGroupName:CA;Replicating Directory Changes In Filtered Set`"

# Set SPN for svc_kerb (for Kerberoasting)
Write-Host "[DC01] Setting SPN for svc_kerb..." -ForegroundColor Yellow
setspn -A HTTP/dev04.lab.local svc_kerb

# Create flag files
Write-Host "[DC01] Creating flag files..." -ForegroundColor Green
$flagsPath = "C:\flags"
New-Item -ItemType Directory -Path $flagsPath -Force | Out-Null

# Stage 5 flag (Kerberoasting)
$stage5Flag = Get-Content "/vagrant/flags/stage5.txt" -ErrorAction SilentlyContinue
if ($stage5Flag) {
    $stage5Flag | Out-File "$flagsPath\stage5.txt" -Encoding ASCII
} else {
    "CTF_{KERBEROASTING_FLAG}" | Out-File "$flagsPath\stage5.txt" -Encoding ASCII
}

# Stage 6 flag (DCSync)
$stage6Flag = Get-Content "/vagrant/flags/stage6.txt" -ErrorAction SilentlyContinue
if ($stage6Flag) {
    $stage6Flag | Out-File "$flagsPath\stage6.txt" -Encoding ASCII
} else {
    "CTF_{DCSYNC_FLAG}" | Out-File "$flagsPath\stage6.txt" -Encoding ASCII
}

# Disable Windows Defender (for lab environment)
Write-Host "[DC01] Disabling Windows Defender..." -ForegroundColor Yellow
Set-MpPreference -DisableRealtimeMonitoring $true
Set-MpPreference -DisableBehaviorMonitoring $true
Set-MpPreference -DisableBlockAtFirstSeen $true
Set-MpPreference -DisableIOAVProtection $true
Set-MpPreference -DisablePrivacyMode $true
Set-MpPreference -SignatureDisableUpdateOnStartupWithoutEngine $true
Set-MpPreference -DisableArchiveScanning $true
Set-MpPreference -DisableIntrusionPreventionSystem $true
Set-MpPreference -DisableScriptScanning $true

# Enable WinRM and disable firewall for internal network
Write-Host "[DC01] Configuring WinRM and firewall..." -ForegroundColor Yellow
Enable-PSRemoting -Force
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False

Write-Host "[DC01] Provisioning completed!" -ForegroundColor Green
Write-Host "[DC01] Domain: lab.local" -ForegroundColor Cyan
Write-Host "[DC01] Domain Admin: Administrator / D@nAdm!n2024" -ForegroundColor Cyan
Write-Host "[DC01] DC IP: 10.0.2.10" -ForegroundColor Cyan