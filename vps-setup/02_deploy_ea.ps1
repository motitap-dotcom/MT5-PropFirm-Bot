#=============================================================================
# PropFirmBot - EA Deployment Script
# Run this AFTER MT5 is installed and you logged into your broker
# Right-click -> Run with PowerShell (as Administrator)
#=============================================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  PropFirmBot - Deploy EA to MT5" -ForegroundColor Cyan
Write-Host "  Step 2: Copy EA files" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$botDir = "C:\PropFirmBot"

# --- Find MT5 Data Folder ---
Write-Host "[1/4] Finding MT5 data folder..." -ForegroundColor Yellow

# MT5 stores EA files in AppData, not Program Files
$terminalDataPath = "$env:APPDATA\MetaQuotes\Terminal"

if (!(Test-Path $terminalDataPath)) {
    Write-Host "[ERROR] MT5 data folder not found!" -ForegroundColor Red
    Write-Host "Make sure MT5 was opened at least once and you logged in." -ForegroundColor Yellow
    Write-Host "Expected: $terminalDataPath" -ForegroundColor Yellow
    exit 1
}

# Find the terminal instance folder (hash-named directory)
$terminalFolders = Get-ChildItem -Path $terminalDataPath -Directory | Where-Object {
    Test-Path "$($_.FullName)\MQL5\Experts"
}

if ($terminalFolders.Count -eq 0) {
    Write-Host "[ERROR] No MT5 terminal data found!" -ForegroundColor Red
    Write-Host "Open MT5, log in to your broker, then try again." -ForegroundColor Yellow
    exit 1
}

# Use the most recently modified terminal folder
$targetTerminal = $terminalFolders | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$mql5Path = "$($targetTerminal.FullName)\MQL5"
$expertsPath = "$mql5Path\Experts"

Write-Host "[OK] MT5 data found: $mql5Path" -ForegroundColor Green

# --- Create EA directory ---
Write-Host ""
Write-Host "[2/4] Creating PropFirmBot EA folder..." -ForegroundColor Yellow

$eaDestDir = "$expertsPath\PropFirmBot"
if (!(Test-Path $eaDestDir)) {
    New-Item -ItemType Directory -Path $eaDestDir -Force | Out-Null
}
Write-Host "[OK] EA folder: $eaDestDir" -ForegroundColor Green

# --- Copy EA files ---
Write-Host ""
Write-Host "[3/4] Copying EA files..." -ForegroundColor Yellow

# Source: where this script is located (should be in vps-setup/)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$eaSourceDir = "$projectDir\EA"

# If source files aren't next to the script, check C:\PropFirmBot\EA
if (!(Test-Path $eaSourceDir)) {
    $eaSourceDir = "$botDir\EA"
}

if (!(Test-Path $eaSourceDir)) {
    Write-Host "[ERROR] EA source files not found!" -ForegroundColor Red
    Write-Host "Expected at: $eaSourceDir" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Copy the project files to C:\PropFirmBot\ first:" -ForegroundColor Yellow
    Write-Host "  C:\PropFirmBot\EA\PropFirmBot.mq5" -ForegroundColor White
    Write-Host "  C:\PropFirmBot\EA\SignalEngine.mqh" -ForegroundColor White
    Write-Host "  C:\PropFirmBot\EA\RiskManager.mqh" -ForegroundColor White
    Write-Host "  C:\PropFirmBot\EA\TradeManager.mqh" -ForegroundColor White
    Write-Host "  C:\PropFirmBot\EA\Guardian.mqh" -ForegroundColor White
    Write-Host "  C:\PropFirmBot\EA\Dashboard.mqh" -ForegroundColor White
    Write-Host "  C:\PropFirmBot\EA\TradeJournal.mqh" -ForegroundColor White
    exit 1
}

$eaFiles = @(
    "PropFirmBot.mq5",
    "SignalEngine.mqh",
    "RiskManager.mqh",
    "TradeManager.mqh",
    "Guardian.mqh",
    "Dashboard.mqh",
    "TradeJournal.mqh"
)

$copied = 0
foreach ($file in $eaFiles) {
    $src = "$eaSourceDir\$file"
    $dst = "$eaDestDir\$file"
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Host "  [OK] $file" -ForegroundColor Green
        $copied++
    } else {
        Write-Host "  [SKIP] $file (not found)" -ForegroundColor Yellow
    }
}

Write-Host "[OK] Copied $copied/$($eaFiles.Count) files" -ForegroundColor Green

# --- Copy config files ---
Write-Host ""
Write-Host "[4/4] Copying config files..." -ForegroundColor Yellow

$configSourceDir = "$projectDir\configs"
if (!(Test-Path $configSourceDir)) {
    $configSourceDir = "$botDir\configs"
}

$configDestDir = "$mql5Path\Files\PropFirmBot"
if (!(Test-Path $configDestDir)) {
    New-Item -ItemType Directory -Path $configDestDir -Force | Out-Null
}

if (Test-Path $configSourceDir) {
    Get-ChildItem -Path $configSourceDir -Filter "*.json" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination "$configDestDir\$($_.Name)" -Force
        Write-Host "  [OK] $($_.Name)" -ForegroundColor Green
    }
} else {
    Write-Host "  [SKIP] Config folder not found" -ForegroundColor Yellow
}

# --- Create auto-start task for MT5 ---
Write-Host ""
Write-Host "Setting up MT5 auto-start on reboot..." -ForegroundColor Yellow

# Find terminal64.exe
$mt5Exe = $null
$searchPaths = @(
    "$env:ProgramFiles\MetaTrader 5\terminal64.exe",
    "${env:ProgramFiles(x86)}\MetaTrader 5\terminal64.exe",
    "$env:LOCALAPPDATA\Programs\MetaTrader 5\terminal64.exe"
)

foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        $mt5Exe = $path
        break
    }
}

if ($mt5Exe) {
    # Create scheduled task for auto-start
    $action = New-ScheduledTaskAction -Execute $mt5Exe
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    Register-ScheduledTask -TaskName "MT5_AutoStart" -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    Write-Host "[OK] MT5 will auto-start on reboot" -ForegroundColor Green
} else {
    Write-Host "[SKIP] MT5 exe not found for auto-start" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  EA Deployment Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS IN MT5:" -ForegroundColor Cyan
Write-Host "1. Open MT5 (or restart it)" -ForegroundColor White
Write-Host "2. In Navigator panel -> Expert Advisors" -ForegroundColor White
Write-Host "3. Find 'PropFirmBot' folder" -ForegroundColor White
Write-Host "4. Right-click 'PropFirmBot' -> Compile" -ForegroundColor White
Write-Host "5. Drag 'PropFirmBot' onto a chart" -ForegroundColor White
Write-Host "6. Enable 'Allow Algo Trading' (top toolbar)" -ForegroundColor White
Write-Host ""
Write-Host "IMPORTANT SETTINGS when attaching EA:" -ForegroundColor Yellow
Write-Host "  - Common tab: Allow Algo Trading = YES" -ForegroundColor White
Write-Host "  - Inputs tab: Set your account size" -ForegroundColor White
Write-Host "  - Inputs tab: Challenge Mode = true" -ForegroundColor White
Write-Host "  - Inputs tab: Risk Per Trade = 0.5" -ForegroundColor White
Write-Host ""
Write-Host "Run 03_monitor.ps1 to set up monitoring" -ForegroundColor Cyan
Write-Host ""
