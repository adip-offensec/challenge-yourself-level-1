# WEB02 Provisioning Script
# Sets up public web server with SQL injection and privilege escalation vectors

Write-Host "[WEB02] Starting provisioning..." -ForegroundColor Green

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force

# Disable Windows Defender
Write-Host "[WEB02] Disabling Windows Defender..." -ForegroundColor Yellow
Set-MpPreference -DisableRealtimeMonitoring $true
Set-MpPreference -DisableBehaviorMonitoring $true
Set-MpPreference -DisableBlockAtFirstSeen $true

# Install IIS
Write-Host "[WEB02] Installing IIS..." -ForegroundColor Yellow
Install-WindowsFeature -Name Web-Server, Web-Asp-Net45, Web-Mgmt-Console -IncludeManagementTools

# Install Chocolatey (if not present)
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "[WEB02] Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Install SQL Server Express
Write-Host "[WEB02] Installing SQL Server Express 2019..." -ForegroundColor Yellow
choco install sql-server-express2019 -y --params="'/INSTANCEID:MSSQLSERVER /INSTANCENAME:MSSQLSERVER /SECURITYMODE=SQL /SAPWD:SQLAdmin123! /SQLSVCACCOUNT:NT AUTHORITY\NETWORK SERVICE /SQLSYSADMINACCOUNTS:BUILTIN\Administrators'"

# Wait for SQL Server installation
Write-Host "[WEB02] Waiting for SQL Server to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

# Enable xp_cmdshell
Write-Host "[WEB02] Configuring SQL Server xp_cmdshell..." -ForegroundColor Yellow
$sqlCommand = @"
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
"@

# Execute SQL command using sqlcmd
& sqlcmd -S localhost -Q $sqlCommand

# Create database and user
Write-Host "[WEB02] Creating webapp database..." -ForegroundColor Yellow
$createDb = @"
CREATE DATABASE webapp;
GO
USE webapp;
GO
CREATE TABLE users (id INT IDENTITY(1,1), username VARCHAR(50), password VARCHAR(50));
INSERT INTO users (username, password) VALUES ('admin', 'admin'), ('user', 'password123');
GO
CREATE LOGIN webuser WITH PASSWORD = 'WebDbPass!';
GO
USE webapp;
GO
CREATE USER webuser FOR LOGIN webuser;
GO
EXEC sp_addrolemember 'db_owner', 'webuser';
EXEC sp_addsrvrolemember 'webuser', 'sysadmin';
GO
"@

& sqlcmd -S localhost -Q $createDb

# Create vulnerable ASP.NET application
Write-Host "[WEB02] Creating vulnerable web application..." -ForegroundColor Yellow
$webRoot = "C:\inetpub\wwwroot"
$loginPage = @"
<%@ Page Language="C#" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<!DOCTYPE html>
<html>
<head>
    <title>Login - Vulnerable App</title>
</head>
<body>
    <h2>Login</h2>
    <form method="post">
        Username: <input type="text" name="username" /><br />
        Password: <input type="password" name="password" /><br />
        <input type="submit" value="Login" />
    </form>
    <%
        if (Request.Form["username"] != null) {
            string connectionString = "Server=localhost;Database=webapp;User Id=webuser;Password=WebDbPass!;";
            string query = "SELECT * FROM users WHERE username = '" + Request.Form["username"] + "' AND password = '" + Request.Form["password"] + "'";
            
            using (SqlConnection conn = new SqlConnection(connectionString)) {
                conn.Open();
                SqlCommand cmd = new SqlCommand(query, conn);
                SqlDataReader reader = cmd.ExecuteReader();
                
                if (reader.HasRows) {
                    Response.Write("<h3>Login successful!</h3>");
                    while (reader.Read()) {
                        Response.Write("User: " + reader["username"] + "<br />");
                    }
                } else {
                    Response.Write("<h3>Login failed!</h3>");
                }
                reader.Close();
            }
        }
    %>
    <hr />
    <small>Debug: Try ' OR 1=1-- as username</small>
</body>
</html>
"@

$loginPage | Out-File "$webRoot\login.aspx" -Encoding ASCII

# Create another page with SQL injection demonstration
$searchPage = @"
<%@ Page Language="C#" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<!DOCTYPE html>
<html>
<head>
    <title>Search Users</title>
</head>
<body>
    <h2>Search Users</h2>
    <form method="get">
        Search: <input type="text" name="q" value="<%= Request.QueryString["q"] %>" />
        <input type="submit" value="Search" />
    </form>
    <%
        if (Request.QueryString["q"] != null) {
            string connectionString = "Server=localhost;Database=webapp;User Id=webuser;Password=WebDbPass!;";
            string query = "SELECT * FROM users WHERE username LIKE '%" + Request.QueryString["q"] + "%'";
            
            using (SqlConnection conn = new SqlConnection(connectionString)) {
                conn.Open();
                SqlCommand cmd = new SqlCommand(query, conn);
                SqlDataReader reader = cmd.ExecuteReader();
                
                Response.Write("<table border='1'><tr><th>ID</th><th>Username</th><th>Password</th></tr>");
                while (reader.Read()) {
                    Response.Write("<tr>");
                    Response.Write("<td>" + reader["id"] + "</td>");
                    Response.Write("<td>" + reader["username"] + "</td>");
                    Response.Write("<td>" + reader["password"] + "</td>");
                    Response.Write("</tr>");
                }
                Response.Write("</table>");
                reader.Close();
            }
        }
    %>
</body>
</html>
"@

$searchPage | Out-File "$webRoot\search.aspx" -Encoding ASCII

# Create unquoted service path vulnerability
Write-Host "[WEB02] Creating unquoted service path vulnerability..." -ForegroundColor Yellow
$servicePath = "C:\Program Files\Vuln Service"
New-Item -ItemType Directory -Path $servicePath -Force | Out-Null

# Create a dummy service executable (simple C# program)
$serviceExe = @"
using System;
using System.Threading;

namespace VulnService
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Vulnerable Service Running...");
            Thread.Sleep(Timeout.Infinite);
        }
    }
}
"@

$serviceExe | Out-File "$servicePath\service.cs" -Encoding ASCII

# Compile the service (requires .NET Framework)
& "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /out:"$servicePath\service.exe" "$servicePath\service.cs"

# If compilation fails, create a simple executable using PowerShell
if (-not (Test-Path "$servicePath\service.exe")) {
    Copy-Item "C:\Windows\System32\cmd.exe" "$servicePath\service.exe"
}

# Set permissions so NETWORK SERVICE can write to folder
$acl = Get-Acl $servicePath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("NETWORK SERVICE", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
Set-Acl $servicePath $acl

# Create the service with unquoted path
$serviceName = "VulnService"
if (-not (Get-Service $serviceName -ErrorAction SilentlyContinue)) {
    New-Service -Name $serviceName -BinaryPathName "C:\Program Files\Vuln Service\service.exe" -StartupType Automatic -DisplayName "Vulnerable Service"
    Write-Host "[WEB02] Created service with unquoted path." -ForegroundColor Green
}

# Store credentials for lateral movement
Write-Host "[WEB02] Storing credentials for lateral movement..." -ForegroundColor Yellow
$credsPath = "C:\Users\Public\creds.txt"
"files_admin:FilesAdm!456" | Out-File $credsPath -Encoding ASCII

# Create flag files
Write-Host "[WEB02] Creating flag files..." -ForegroundColor Green
$flagsPath = "C:\flags"
New-Item -ItemType Directory -Path $flagsPath -Force | Out-Null

# Stage 1 flag (SQLi)
$stage1Flag = Get-Content "/vagrant/flags/stage1.txt" -ErrorAction SilentlyContinue
if ($stage1Flag) {
    $stage1Flag | Out-File "$flagsPath\stage1.txt" -Encoding ASCII
} else {
    "CTF_{SQLI_FLAG}" | Out-File "$flagsPath\stage1.txt" -Encoding ASCII
}

# Stage 2 flag (Privilege escalation)
$stage2Flag = Get-Content "/vagrant/flags/stage2.txt" -ErrorAction SilentlyContinue
if ($stage2Flag) {
    $stage2Flag | Out-File "$flagsPath\stage2.txt" -Encoding ASCII
} else {
    "CTF_{PRIVESC_FLAG}" | Out-File "$flagsPath\stage2.txt" -Encoding ASCII
}

# Place flag in web directory for easy access (optional)
Copy-Item "$flagsPath\stage1.txt" "$webRoot\flag.txt"

# Configure firewall to allow web traffic
Write-Host "[WEB02] Configuring firewall..." -ForegroundColor Yellow
New-NetFirewallRule -DisplayName "HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
New-NetFirewallRule -DisplayName "RDP" -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False

# Enable WinRM
Enable-PSRemoting -Force

# Join domain (requires reboot)
Write-Host "[WEB02] Joining domain lab.local..." -ForegroundColor Yellow
$domainCred = New-Object System.Management.Automation.PSCredential("LAB\Administrator", (ConvertTo-SecureString "D@nAdm!n2024" -AsPlainText -Force))
Add-Computer -DomainName "lab.local" -Credential $domainCred -Restart -Force

Write-Host "[WEB02] Provisioning completed! System will restart to join domain." -ForegroundColor Green
Write-Host "[WEB02] Web server: http://10.0.1.20/login.aspx" -ForegroundColor Cyan
Write-Host "[WEB02] SQL Server: localhost, user: webuser, password: WebDbPass!" -ForegroundColor Cyan