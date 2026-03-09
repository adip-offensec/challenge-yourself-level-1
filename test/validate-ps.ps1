# PowerShell script validation
param([string]$ScriptPath)

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script not found: $ScriptPath"
    exit 1
}

# Load script content
$content = Get-Content $ScriptPath -Raw

# Check for syntax errors
$errors = $null
$tokens = $null
$parsed = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$tokens)

# Simple validation - try to parse as script block
try {
    $scriptBlock = [ScriptBlock]::Create($content)
    Write-Host "[OK] $ScriptPath - Syntax valid" -ForegroundColor Green
    return $true
} catch {
    Write-Host "[ERROR] $ScriptPath - Syntax error: $_" -ForegroundColor Red
    return $false
}