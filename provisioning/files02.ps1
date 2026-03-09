# FILES02 Provisioning Script
# Sets up file server with shares and local admin for files_admin

Write-Host "[FILES02] Starting provisioning..." -ForegroundColor Green

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force

# Disable Windows Defender
Write-Host "[FILES02] Disabling Windows Defender..." -ForegroundColor Yellow
Set-MpPreference -DisableRealtimeMonitoring $true

# Join domain
Write-Host "[FILES02] Joining domain lab.local..." -ForegroundColor Yellow
$domainCred = New-Object System.Management.Automation.PSCredential("LAB\Administrator", (ConvertTo-SecureString "D@nAdm!n2024" -AsPlainText -Force))
Add-Computer -DomainName "lab.local" -Credential $domainCred -Restart -Force

# After reboot, continue (Vagrant will re-run provisioner? Not ideal)
# We'll split: if already domain joined, skip.

# Check if already domain joined
if ((Get-WmiObject Win32_ComputerSystem).PartOfDomain) {
    Write-Host "[FILES02] Already domain joined, continuing configuration..." -ForegroundColor Green
    
    # Install File Server role
    Write-Host "[FILES02] Installing File Server role..." -ForegroundColor Yellow
    Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools
    
    # Create shared folder
    $sharePath = "C:\SharedData"
    New-Item -ItemType Directory -Path $sharePath -Force | Out-Null
    
    # Create some dummy files
    "Confidential Document - Budget 2024" | Out-File "$sharePath\budget.docx" -Encoding ASCII
    "Employee list with salaries" | Out-File "$sharePath\employees.xlsx" -Encoding ASCII
    "Network diagram with passwords" | Out-File "$sharePath\diagram.pdf" -Encoding ASCII
    
    # Create share
    New-SmbShare -Name "Data" -Path $sharePath -FullAccess "LAB\files_admin", "LAB\Administrator" -ReadAccess "Everyone"
    
    # Add files_admin to local Administrators group
    Write-Host "[FILES02] Adding files_admin to local Administrators..." -ForegroundColor Yellow
    Add-LocalGroupMember -Group "Administrators" -Member "LAB\files_admin"
    
    # Create flag file
    $flagsPath = "C:\flags"
    New-Item -ItemType Directory -Path $flagsPath -Force | Out-Null
    
    $stage3Flag = Get-Content "/vagrant/flags/stage3.txt" -ErrorAction SilentlyContinue
    if ($stage3Flag) {
        $stage3Flag | Out-File "$flagsPath\stage3.txt" -Encoding ASCII
    } else {
        "CTF_{FILESHARE_FLAG}" | Out-File "$flagsPath\stage3.txt" -Encoding ASCII
    }
    
    # Also place flag in share
    Copy-Item "$flagsPath\stage3.txt" "$sharePath\flag.txt"
    
    # Disable firewall
    Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False
    
    # Enable RDP
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    
    Write-Host "[FILES02] Provisioning completed!" -ForegroundColor Green
    Write-Host "[FILES02] File share: \\FILES02\Data" -ForegroundColor Cyan
    Write-Host "[FILES02] Local admin: files_admin / FilesAdm!456" -ForegroundColor Cyan
} else {
    Write-Host "[FILES02] Domain join required. Restarting..." -ForegroundColor Yellow
    # Exit with reboot code
    exit 3010
}