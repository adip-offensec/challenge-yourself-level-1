# Attack Path Lab Provisioning Script (Windows)
Write-Host "=== Attack Path Lab Provisioning ===" -ForegroundColor Cyan
Write-Host "This script will provision all VMs in recommended order." -ForegroundColor Yellow
Write-Host "Note: Windows VMs may reboot during domain join." -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Continue? (y/n)"
if ($confirm -notmatch "^[Yy]$") {
    Write-Host "Aborted." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "1. Provisioning Kali Linux (attacker)..." -ForegroundColor Green
vagrant provision kali

Write-Host ""
Write-Host "2. Provisioning DC01 (domain controller)..." -ForegroundColor Green
vagrant provision dc01

Write-Host ""
Write-Host "Waiting for DC01 to stabilize..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host ""
Write-Host "3. Provisioning WEB02 (web server)..." -ForegroundColor Green
vagrant provision web02

Write-Host ""
Write-Host "4. Provisioning FILES02 (file server)..." -ForegroundColor Green
vagrant provision files02

Write-Host ""
Write-Host "5. Provisioning CLIENT02 (client workstation)..." -ForegroundColor Green
vagrant provision client02

Write-Host ""
Write-Host "6. Provisioning DEV04 (development machine)..." -ForegroundColor Green
vagrant provision dev04

Write-Host ""
Write-Host "7. Provisioning PROD01 (production server)..." -ForegroundColor Green
vagrant provision prod01

Write-Host ""
Write-Host "=== Provisioning Complete ===" -ForegroundColor Cyan
Write-Host "Web frontend: http://10.0.1.10:8080" -ForegroundColor Green
Write-Host "Kali SSH: vagrant ssh kali" -ForegroundColor Green
Write-Host ""
Write-Host "If any VM failed, run 'vagrant provision <vmname>' individually." -ForegroundColor Yellow