# OpenClaw Cloud Auto-Deployment Script (English Version - Robust)
$ErrorActionPreference = "Stop"

# Check Administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run as Administrator for best results."
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   OpenClaw Cloud Deployment Helper" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Get Server Info
$ServerIP = Read-Host "Enter your Server Public IP"
if ([string]::IsNullOrWhiteSpace($ServerIP)) {
    Write-Error "IP Address cannot be empty."
    exit
}

# Prompt for username (default to ubuntu)
$RemoteUser = Read-Host "Enter username (default: ubuntu)"
if ([string]::IsNullOrWhiteSpace($RemoteUser)) {
    $RemoteUser = "ubuntu"
}
Write-Host "Using username: $RemoteUser" -ForegroundColor Gray

# 2. Connectivity Check
Write-Host "`n[Checking] Testing connection to $ServerIP (Port 22)..." -ForegroundColor Gray
try {
    $tcpTest = Test-NetConnection -ComputerName $ServerIP -Port 22 -WarningAction SilentlyContinue
    if (-not $tcpTest.TcpTestSucceeded) {
        Write-Error "ERROR: Cannot connect to $ServerIP on port 22."
        Write-Host "Possible causes:" -ForegroundColor Yellow
        Write-Host "1. Incorrect IP address"
        Write-Host "2. Server firewall/security group blocks port 22"
        Write-Host "3. Server is not running"
        exit
    }
    Write-Host "Connection test passed!" -ForegroundColor Green
} catch {
    Write-Warning "Could not perform auto-check. Proceeding anyway..."
}

Write-Host "`n[Note] If the script freezes, it's usually a network issue." -ForegroundColor Yellow
Write-Host "Please enter the server password when prompted (input will be hidden)." -ForegroundColor Yellow

# 3. Create Remote Directory
Write-Host "`n[Step 1/3] Initializing remote server..." -ForegroundColor Green
try {
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ${RemoteUser}@${ServerIP} "mkdir -p ~/openclaw-deploy"
} catch {
    Write-Error "SSH Connection failed. Please check your password or username."
    exit
}

# 4. Upload Files
Write-Host "`n[Step 2/3] Uploading deployment files..." -ForegroundColor Green
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = "D:\OpenClaw" }

$FilesToUpload = @("docker-compose.yml", "deploy_openclaw.sh", "arbitrage_monitor.py", "Dockerfile.monitor")
foreach ($File in $FilesToUpload) {
    $FilePath = Join-Path $ScriptDir $File
    if (Test-Path $FilePath) {
        Write-Host "Uploading: $File ..."
        scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 $FilePath ${RemoteUser}@${ServerIP}:~/openclaw-deploy/
    }
}

# 5. Execute Remote Script
Write-Host "`n[Step 3/3] Executing remote deployment script..." -ForegroundColor Green
Write-Host "Note: This may take a few minutes to install Docker..." -ForegroundColor Gray

# FIX: Convert line endings from Windows (CRLF) to Linux (LF) using sed before running
# This prevents "/bin/bash^M: bad interpreter" errors
$RemoteCommand = "cd ~/openclaw-deploy && " +
                 "sed -i 's/\r$//' deploy_openclaw.sh && " + 
                 "chmod +x deploy_openclaw.sh && " + 
                 "sudo ./deploy_openclaw.sh"

ssh -t -o StrictHostKeyChecking=no ${RemoteUser}@${ServerIP} $RemoteCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "   DEPLOYMENT SUCCESSFUL!" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "`n[Secure Access Guide]" -ForegroundColor Yellow
    Write-Host "Run the following command in a NEW PowerShell window to create a secure tunnel:"
    Write-Host "`nssh -L 18789:127.0.0.1:18789 ${RemoteUser}@${ServerIP}`n" -ForegroundColor White -BackgroundColor Black
    Write-Host "Then open browser at: http://localhost:18789"
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
