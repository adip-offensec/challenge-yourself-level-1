# PROD01 Provisioning Script
# Sets up production server with final flag

Write-Host "[PROD01] Starting provisioning..." -ForegroundColor Green

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force

# Disable Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $true

# Join domain
Write-Host "[PROD01] Joining domain lab.local..." -ForegroundColor Yellow
$domainCred = New-Object System.Management.Automation.PSCredential("LAB\Administrator", (ConvertTo-SecureString "D@nAdm!n2024" -AsPlainText -Force))
Add-Computer -DomainName "lab.local" -Credential $domainCred -Restart -Force

if ((Get-WmiObject Win32_ComputerSystem).PartOfDomain) {
    Write-Host "[PROD01] Already domain joined, continuing configuration..." -ForegroundColor Green
    
    # Create final flag on Administrator desktop
    $adminDesktop = "C:\Users\Administrator\Desktop"
    if (-not (Test-Path $adminDesktop)) {
        New-Item -ItemType Directory -Path $adminDesktop -Force | Out-Null
    }
    
    $stage7Flag = Get-Content "/vagrant/flags/stage7.txt" -ErrorAction SilentlyContinue
    if ($stage7Flag) {
        $stage7Flag | Out-File "$adminDesktop\final.txt" -Encoding ASCII
    } else {
        "CTF_{DOMAIN_ADMIN_FLAG}" | Out-File "$adminDesktop\final.txt" -Encoding ASCII
    }
    
    # Create a dummy web service for realism
    Write-Host "[PROD01] Installing IIS for realism..." -ForegroundColor Yellow
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools
    
    # Disable firewall
    Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False
    
    Write-Host "[PROD01] Provisioning completed!" -ForegroundColor Green
    Write-Host "[PROD01] Final flag located at C:\Users\Administrator\Desktop\final.txt" -ForegroundColor Cyan
} else {
    Write-Host "[PROD01] Domain join required. Restarting..." -ForegroundColor Yellow
    exit 3010
}