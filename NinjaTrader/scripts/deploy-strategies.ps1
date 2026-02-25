# ============================================================
# Deploy NinjaTrader Strategies
# Run this after NinjaTrader 8 is installed and opened once
# ============================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Deploy NinjaTrader Strategies" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Find NinjaTrader strategies folder ---
$ntStrategiesPath = "$env:USERPROFILE\Documents\NinjaTrader 8\bin\Custom\Strategies"

if (-not (Test-Path $ntStrategiesPath)) {
    Write-Host "[ERROR] NinjaTrader strategies folder not found!" -ForegroundColor Red
    Write-Host "Expected: $ntStrategiesPath" -ForegroundColor Red
    Write-Host "" -ForegroundColor Red
    Write-Host "Make sure you:" -ForegroundColor Yellow
    Write-Host "  1. Installed NinjaTrader 8" -ForegroundColor Yellow
    Write-Host "  2. Opened it at least once" -ForegroundColor Yellow
    Write-Host "  3. Logged in" -ForegroundColor Yellow
    exit 1
}

# --- Pull latest code ---
$repoPath = "C:\NinjaTrader-Bot\MT5-PropFirm-Bot"

if (Test-Path $repoPath) {
    Write-Host "Pulling latest code..." -ForegroundColor Yellow
    Set-Location $repoPath
    git pull origin claude/ninjatrader-trading-bot-PxnQr
} else {
    Write-Host "[ERROR] Repository not found at $repoPath" -ForegroundColor Red
    Write-Host "Run setup-windows-vps.ps1 first!" -ForegroundColor Red
    exit 1
}

# --- Copy strategy files ---
$repoStrategies = "$repoPath\NinjaTrader\Strategies"

Write-Host "" -ForegroundColor White
Write-Host "Deploying strategies..." -ForegroundColor Yellow

$files = @("MarchMadnessBot.cs", "MadnessScalper.cs")

foreach ($file in $files) {
    $source = "$repoStrategies\$file"
    $dest = "$ntStrategiesPath\$file"

    if (Test-Path $source) {
        Copy-Item $source -Destination $dest -Force
        Write-Host "  [OK] $file deployed" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] $file not found in repo!" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Now in NinjaTrader:" -ForegroundColor White
Write-Host "  1. Open NinjaScript Editor (New > NinjaScript Editor)" -ForegroundColor White
Write-Host "  2. Press F5 to compile" -ForegroundColor White
Write-Host "  3. Check for green 'Compile successful' message" -ForegroundColor White
Write-Host ""
