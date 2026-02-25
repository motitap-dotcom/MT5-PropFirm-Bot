# ============================================================
# NinjaTrader 8 - Windows VPS Setup Script
# Server: 217.77.2.74 (Contabo Windows VPS)
# Purpose: March Market Madness Competition
# ============================================================
# Run this script on the Windows VPS via RDP (Remote Desktop)
# Open PowerShell as Administrator and paste this entire script
# ============================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  NinjaTrader 8 - Windows VPS Setup" -ForegroundColor Cyan
Write-Host "  Server: 217.77.2.74" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Create working directories ---
Write-Host "[1/5] Creating directories..." -ForegroundColor Yellow

$workDir = "C:\NinjaTrader-Bot"
$strategiesDir = "$workDir\Strategies"
$logsDir = "$workDir\Logs"

New-Item -ItemType Directory -Force -Path $workDir | Out-Null
New-Item -ItemType Directory -Force -Path $strategiesDir | Out-Null
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

Write-Host "  [OK] Directories created at $workDir" -ForegroundColor Green

# --- Step 2: Install Git (if not present) ---
Write-Host "[2/5] Checking Git..." -ForegroundColor Yellow

$gitInstalled = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitInstalled) {
    Write-Host "  Downloading Git..." -ForegroundColor Yellow
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe"
    $gitInstaller = "$env:TEMP\git-installer.exe"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing

    Write-Host "  Installing Git (silent)..." -ForegroundColor Yellow
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT /NORESTART" -Wait

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    Write-Host "  [OK] Git installed" -ForegroundColor Green
} else {
    Write-Host "  [OK] Git already installed" -ForegroundColor Green
}

# --- Step 3: Clone repository ---
Write-Host "[3/5] Cloning repository..." -ForegroundColor Yellow

if (Test-Path "$workDir\MT5-PropFirm-Bot") {
    Write-Host "  Repository already exists, pulling latest..." -ForegroundColor Yellow
    Set-Location "$workDir\MT5-PropFirm-Bot"
    git pull origin claude/ninjatrader-trading-bot-PxnQr
} else {
    Set-Location $workDir
    git clone https://github.com/motitap-dotcom/MT5-PropFirm-Bot.git
    Set-Location "$workDir\MT5-PropFirm-Bot"
    git checkout claude/ninjatrader-trading-bot-PxnQr
}

Write-Host "  [OK] Repository ready" -ForegroundColor Green

# --- Step 4: Download NinjaTrader 8 ---
Write-Host "[4/5] NinjaTrader 8 download..." -ForegroundColor Yellow

$ntInstaller = "$env:TEMP\NinjaTrader8Setup.exe"
$ntInstalled = Test-Path "C:\Program Files\NinjaTrader 8\NinjaTrader.exe"

if (-not $ntInstalled) {
    Write-Host "  Downloading NinjaTrader 8..." -ForegroundColor Yellow
    Write-Host "  (This may take a few minutes)" -ForegroundColor Gray

    $ntUrl = "https://ninjatrader.com/GetNinjaTrader"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $ntUrl -OutFile $ntInstaller -UseBasicParsing

        Write-Host "  Downloaded! Starting installer..." -ForegroundColor Yellow
        Write-Host "" -ForegroundColor Yellow
        Write-Host "  ================================================" -ForegroundColor Magenta
        Write-Host "  MANUAL STEP: Install NinjaTrader 8" -ForegroundColor Magenta
        Write-Host "  The installer will open - follow the wizard:" -ForegroundColor Magenta
        Write-Host "  1. Accept license agreement" -ForegroundColor Magenta
        Write-Host "  2. Choose default installation path" -ForegroundColor Magenta
        Write-Host "  3. Click Install and wait" -ForegroundColor Magenta
        Write-Host "  4. When done - come back here" -ForegroundColor Magenta
        Write-Host "  ================================================" -ForegroundColor Magenta
        Write-Host ""

        Start-Process -FilePath $ntInstaller -Wait

    } catch {
        Write-Host "  [!] Auto-download failed." -ForegroundColor Red
        Write-Host "  Please download manually from: https://ninjatrader.com/GetNinjaTrader" -ForegroundColor Yellow
        Write-Host "  Install it, then continue to step 5." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [OK] NinjaTrader 8 already installed" -ForegroundColor Green
}

# --- Step 5: Deploy strategy files ---
Write-Host "[5/5] Deploying strategy files..." -ForegroundColor Yellow

# NinjaTrader strategies folder
$ntStrategiesPath = "$env:USERPROFILE\Documents\NinjaTrader 8\bin\Custom\Strategies"

if (Test-Path $ntStrategiesPath) {
    # Copy strategy files
    $repoStrategies = "$workDir\MT5-PropFirm-Bot\NinjaTrader\Strategies"

    Copy-Item "$repoStrategies\MarchMadnessBot.cs" -Destination $ntStrategiesPath -Force
    Copy-Item "$repoStrategies\MadnessScalper.cs" -Destination $ntStrategiesPath -Force

    Write-Host "  [OK] Strategies deployed to NinjaTrader!" -ForegroundColor Green
    Write-Host "  Path: $ntStrategiesPath" -ForegroundColor Gray
} else {
    Write-Host "  [!] NinjaTrader strategies folder not found yet." -ForegroundColor Yellow
    Write-Host "  Run NinjaTrader 8 once first, then run deploy-strategies.ps1" -ForegroundColor Yellow
}

# --- Summary ---
Write-Host "" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  SETUP COMPLETE!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Open NinjaTrader 8" -ForegroundColor White
Write-Host "  2. Login with your NinjaTrader account" -ForegroundColor White
Write-Host "  3. Connect to competition data feed" -ForegroundColor White
Write-Host "  4. Open NinjaScript Editor (New > NinjaScript Editor)" -ForegroundColor White
Write-Host "  5. Press F5 to compile strategies" -ForegroundColor White
Write-Host "  6. Open chart: ES 03-26, 5 minute" -ForegroundColor White
Write-Host "  7. Add MarchMadnessBot strategy" -ForegroundColor White
Write-Host "  8. Select competition account: CHMMMKV5060" -ForegroundColor White
Write-Host ""
Write-Host "Competition: $20K March Market Madness" -ForegroundColor Yellow
Write-Host "Dates: Mon 02/03/2026 - Sat 07/03/2026" -ForegroundColor Yellow
Write-Host "Account: CHMMMKV5060" -ForegroundColor Yellow
Write-Host ""
