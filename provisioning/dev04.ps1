# DEV04 Provisioning Script
# Sets up development machine with SeImpersonate privilege for dev_user

Write-Host "[DEV04] Starting provisioning..." -ForegroundColor Green

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force

# Disable Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $true

# Join domain
Write-Host "[DEV04] Joining domain lab.local..." -ForegroundColor Yellow
$domainCred = New-Object System.Management.Automation.PSCredential("LAB\Administrator", (ConvertTo-SecureString "D@nAdm!n2024" -AsPlainText -Force))
Add-Computer -DomainName "lab.local" -Credential $domainCred -Restart -Force

if ((Get-WmiObject Win32_ComputerSystem).PartOfDomain) {
    Write-Host "[DEV04] Already domain joined, continuing configuration..." -ForegroundColor Green
    
    # Grant SeImpersonatePrivilege to dev_user
    Write-Host "[DEV04] Granting SeImpersonatePrivilege to dev_user..." -ForegroundColor Yellow
    
    # Method: Use secedit to export security policy, modify, import
    $policyFile = "C:\Windows\Temp\secedit.inf"
    secedit /export /cfg $policyFile /areas USER_RIGHTS
    
    # Read policy file
    $content = Get-Content $policyFile
    
    # Find SeImpersonatePrivilege line
    $newContent = @()
    $found = $false
    foreach ($line in $content) {
        if ($line -match "^SeImpersonatePrivilege\s*=") {
            # Append dev_user to existing list
            $line = $line.Trim()
            if ($line -notlike "*dev_user*") {
                $line = $line + ",LAB\dev_user"
            }
            $found = $true
        }
        $newContent += $line
    }
    
    if (-not $found) {
        # Add new line
        $newContent += "SeImpersonatePrivilege = LAB\dev_user"
    }
    
    # Write modified content
    $newContent | Out-File $policyFile -Encoding ASCII
    
    # Import modified policy
    $dbFile = "C:\Windows\Temp\secedit.sdb"
    secedit /configure /db $dbFile /cfg $policyFile /areas USER_RIGHTS
    
    # Alternative: Use Ntrights if available (not by default)
    
    # Create flag directory
    $flagsPath = "C:\flags"
    New-Item -ItemType Directory -Path $flagsPath -Force | Out-Null
    
    # Stage 4 flag (Privilege escalation)
    $stage4Flag = Get-Content "/vagrant/flags/stage4.txt" -ErrorAction SilentlyContinue
    if ($stage4Flag) {
        $stage4Flag | Out-File "$flagsPath\stage4.txt" -Encoding ASCII
    } else {
        "CTF_{POTATO_FLAG}" | Out-File "$flagsPath\stage4.txt" -Encoding ASCII
    }
    
    # Place JuicyPotato binary for convenience (optional)
    Write-Host "[DEV04] Downloading JuicyPotato..." -ForegroundColor Yellow
    $juicyUrl = "https://github.com/ohpe/juicy-potato/releases/download/v0.1/JuicyPotato.exe"
    $juicyPath = "C:\Tools\JuicyPotato.exe"
    New-Item -ItemType Directory -Path "C:\Tools" -Force | Out-Null
    try {
        Invoke-WebRequest -Uri $juicyUrl -OutFile $juicyPath
    } catch {
        Write-Host "[DEV04] Failed to download JuicyPotato. Manual download required." -ForegroundColor Red
    }
    
    # Disable firewall
    Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False
    
    # Enable RDP
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    
    Write-Host "[DEV04] Provisioning completed!" -ForegroundColor Green
    Write-Host "[DEV04] User: dev_user / DevUser789!" -ForegroundColor Cyan
    Write-Host "[DEV04] SeImpersonatePrivilege granted for potato attacks." -ForegroundColor Cyan
} else {
    Write-Host "[DEV04] Domain join required. Restarting..." -ForegroundColor Yellow
    exit 3010
}