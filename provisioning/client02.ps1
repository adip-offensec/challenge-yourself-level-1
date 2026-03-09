# CLIENT02 Provisioning Script
# Sets up client workstation

Write-Host "[CLIENT02] Starting provisioning..." -ForegroundColor Green

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force

# Disable Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $true

# Join domain
Write-Host "[CLIENT02] Joining domain lab.local..." -ForegroundColor Yellow
$domainCred = New-Object System.Management.Automation.PSCredential("LAB\Administrator", (ConvertTo-SecureString "D@nAdm!n2024" -AsPlainText -Force))
Add-Computer -DomainName "lab.local" -Credential $domainCred -Restart -Force

# After reboot check
if ((Get-WmiObject Win32_ComputerSystem).PartOfDomain) {
    Write-Host "[CLIENT02] Already domain joined, continuing configuration..." -ForegroundColor Green
    
    # Add files_admin to local Administrators group
    Write-Host "[CLIENT02] Adding files_admin to local Administrators..." -ForegroundColor Yellow
    Add-LocalGroupMember -Group "Administrators" -Member "LAB\files_admin"
    
    # Enable RDP
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    
    # Disable firewall
    Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False
    
    # Create some user data
    $desktopPath = "C:\Users\Public\Desktop"
    "Important notes.txt" | Out-File "$desktopPath\notes.txt" -Encoding ASCII
    
    Write-Host "[CLIENT02] Provisioning completed!" -ForegroundColor Green
    Write-Host "[CLIENT02] Access with: files_admin / FilesAdm!456" -ForegroundColor Cyan
} else {
    Write-Host "[CLIENT02] Domain join required. Restarting..." -ForegroundColor Yellow
    exit 3010
}