#=============================================================================
# PropFirmBot - VPS Health Monitor
# Run this to set up auto-monitoring and crash recovery
# Right-click -> Run with PowerShell (as Administrator)
#=============================================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  PropFirmBot - VPS Monitor Setup" -ForegroundColor Cyan
Write-Host "  Step 3: Auto-recovery & Monitoring" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$botDir = "C:\PropFirmBot"
$logsDir = "$botDir\logs"
$scriptsDir = "$botDir\scripts"

foreach ($dir in @($logsDir, $scriptsDir)) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# --- Create MT5 watchdog script ---
Write-Host "[1/3] Creating MT5 watchdog script..." -ForegroundColor Yellow

$watchdogScript = @'
# MT5 Watchdog - Restarts MT5 if it crashes
# Runs every 5 minutes via Scheduled Task

$logFile = "C:\PropFirmBot\logs\watchdog.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Check if MT5 is running
$mt5Process = Get-Process -Name "terminal64" -ErrorAction SilentlyContinue

if ($mt5Process) {
    # MT5 is running - all good
    "$timestamp [OK] MT5 running (PID: $($mt5Process.Id))" | Out-File $logFile -Append
} else {
    # MT5 is NOT running - restart it
    "$timestamp [ALERT] MT5 not running! Restarting..." | Out-File $logFile -Append

    # Find MT5 exe
    $mt5Paths = @(
        "$env:ProgramFiles\MetaTrader 5\terminal64.exe",
        "${env:ProgramFiles(x86)}\MetaTrader 5\terminal64.exe",
        "$env:LOCALAPPDATA\Programs\MetaTrader 5\terminal64.exe"
    )

    foreach ($path in $mt5Paths) {
        if (Test-Path $path) {
            Start-Process -FilePath $path
            "$timestamp [OK] MT5 restarted from: $path" | Out-File $logFile -Append
            break
        }
    }
}

# Keep log file manageable (last 1000 lines)
if (Test-Path $logFile) {
    $lines = Get-Content $logFile -Tail 1000
    $lines | Set-Content $logFile
}
'@

$watchdogPath = "$scriptsDir\mt5_watchdog.ps1"
$watchdogScript | Out-File $watchdogPath -Encoding UTF8
Write-Host "[OK] Watchdog script created" -ForegroundColor Green

# --- Create daily report script ---
Write-Host ""
Write-Host "[2/3] Creating daily report script..." -ForegroundColor Yellow

$dailyReportScript = @'
# Daily VPS Health Report
# Runs daily at 00:00 UTC

$logFile = "C:\PropFirmBot\logs\daily_report.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$report = @"
========================================
  DAILY VPS HEALTH REPORT
  $timestamp
========================================

--- System ---
Uptime: $((Get-CimInstance Win32_OperatingSystem).LastBootUpTime)
CPU Usage: $([math]::Round((Get-CimInstance Win32_Processor).LoadPercentage, 1))%
RAM Used: $([math]::Round((Get-CimInstance Win32_OperatingSystem | ForEach-Object { ($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) / $_.TotalVisibleMemorySize * 100 }), 1))%
Disk Free: $([math]::Round((Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" | ForEach-Object { $_.FreeSpace / $_.Size * 100 }), 1))%

--- MT5 Status ---
MT5 Running: $(if (Get-Process -Name "terminal64" -ErrorAction SilentlyContinue) { "YES" } else { "NO - CHECK IMMEDIATELY!" })

--- Watchdog Log (last 10 entries) ---
$(if (Test-Path "C:\PropFirmBot\logs\watchdog.log") { Get-Content "C:\PropFirmBot\logs\watchdog.log" -Tail 10 } else { "No watchdog log yet" })

========================================
"@

$report | Out-File $logFile -Append
Write-Host $report
'@

$dailyReportPath = "$scriptsDir\daily_report.ps1"
$dailyReportScript | Out-File $dailyReportPath -Encoding UTF8
Write-Host "[OK] Daily report script created" -ForegroundColor Green

# --- Register scheduled tasks ---
Write-Host ""
Write-Host "[3/3] Registering scheduled tasks..." -ForegroundColor Yellow

# Watchdog: every 5 minutes
$watchdogAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$watchdogPath`""
$watchdogTrigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -Once -At (Get-Date)
$watchdogSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName "MT5_Watchdog" -Action $watchdogAction -Trigger $watchdogTrigger -Settings $watchdogSettings -Force | Out-Null
Write-Host "[OK] Watchdog task: every 5 minutes" -ForegroundColor Green

# Daily report: midnight
$reportAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$dailyReportPath`""
$reportTrigger = New-ScheduledTaskTrigger -Daily -At "00:00"
$reportSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName "MT5_DailyReport" -Action $reportAction -Trigger $reportTrigger -Settings $reportSettings -Force | Out-Null
Write-Host "[OK] Daily report task: midnight" -ForegroundColor Green

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Monitoring Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Active Tasks:" -ForegroundColor Cyan
Write-Host "  [*] MT5_AutoStart  - Starts MT5 on boot" -ForegroundColor White
Write-Host "  [*] MT5_Watchdog   - Checks MT5 every 5 min" -ForegroundColor White
Write-Host "  [*] MT5_DailyReport - System health at midnight" -ForegroundColor White
Write-Host ""
Write-Host "Logs location: C:\PropFirmBot\logs\" -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  YOUR VPS IS READY FOR TRADING!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Quick checklist:" -ForegroundColor Cyan
Write-Host "  [ ] MT5 is open and logged in" -ForegroundColor White
Write-Host "  [ ] PropFirmBot EA is compiled" -ForegroundColor White
Write-Host "  [ ] EA is attached to chart" -ForegroundColor White
Write-Host "  [ ] Algo Trading is enabled" -ForegroundColor White
Write-Host "  [ ] Smiley face shows in top-right of chart" -ForegroundColor White
Write-Host ""
