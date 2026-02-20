#=============================================================================
# PropFirmBot - MT5 Auto-Installer for Windows VPS
# Run this script FIRST after connecting to your VPS via Remote Desktop
# Right-click -> Run with PowerShell (as Administrator)
#=============================================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  PropFirmBot - MT5 VPS Setup Script" -ForegroundColor Cyan
Write-Host "  Step 1: Install MetaTrader 5" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Create working directories ---
$botDir = "C:\PropFirmBot"
$downloadDir = "$botDir\downloads"
$logsDir = "$botDir\logs"

foreach ($dir in @($botDir, $downloadDir, $logsDir)) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "[OK] Created: $dir" -ForegroundColor Green
    }
}

# --- Download MT5 ---
Write-Host ""
Write-Host "[1/3] Downloading MetaTrader 5..." -ForegroundColor Yellow
$mt5Url = "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
$mt5Installer = "$downloadDir\mt5setup.exe"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($mt5Url, $mt5Installer)
    Write-Host "[OK] MT5 downloaded successfully!" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to download MT5: $_" -ForegroundColor Red
    Write-Host "Try manually: $mt5Url" -ForegroundColor Yellow
    exit 1
}

# --- Install MT5 (silent) ---
Write-Host ""
Write-Host "[2/3] Installing MetaTrader 5 (silent install)..." -ForegroundColor Yellow
Start-Process -FilePath $mt5Installer -ArgumentList "/auto" -Wait
Write-Host "[OK] MT5 installation completed!" -ForegroundColor Green

# --- Find MT5 installation path ---
Write-Host ""
Write-Host "[3/3] Locating MT5 installation..." -ForegroundColor Yellow

$possiblePaths = @(
    "$env:ProgramFiles\MetaTrader 5",
    "${env:ProgramFiles(x86)}\MetaTrader 5",
    "$env:APPDATA\MetaQuotes\Terminal",
    "$env:LOCALAPPDATA\Programs\MetaTrader 5"
)

$mt5Path = $null
foreach ($path in $possiblePaths) {
    if (Test-Path "$path\terminal64.exe") {
        $mt5Path = $path
        break
    }
}

if ($mt5Path) {
    Write-Host "[OK] MT5 found at: $mt5Path" -ForegroundColor Green
    # Save path for next script
    $mt5Path | Out-File "$botDir\mt5_path.txt" -Encoding UTF8
} else {
    Write-Host "[WARN] MT5 path not auto-detected." -ForegroundColor Yellow
    Write-Host "After MT5 opens, note the installation path." -ForegroundColor Yellow
}

# --- Configure Windows for 24/7 operation ---
Write-Host ""
Write-Host "Configuring Windows for 24/7 operation..." -ForegroundColor Yellow

# Disable sleep/hibernate
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change monitor-timeout-ac 0
Write-Host "[OK] Sleep/hibernate disabled" -ForegroundColor Green

# Disable Windows Update auto-restart
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (!(Test-Path $wuPath)) {
    New-Item -Path $wuPath -Force | Out-Null
}
Set-ItemProperty -Path $wuPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord
Write-Host "[OK] Auto-restart after updates disabled" -ForegroundColor Green

# Set high performance power plan
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
Write-Host "[OK] High performance power plan set" -ForegroundColor Green

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  MT5 Installation Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host "1. MT5 should open automatically" -ForegroundColor White
Write-Host "2. Log in with your BROKER account" -ForegroundColor White
Write-Host "3. Then run: 02_deploy_ea.ps1" -ForegroundColor White
Write-Host ""
