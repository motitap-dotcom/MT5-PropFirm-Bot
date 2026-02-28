#!/bin/bash
# PropFirmBot - Full Status Check
# Runs on VPS via GitHub Actions

TODAY=$(date '+%Y%m%d')
NOW=$(date '+%Y-%m-%d %H:%M:%S UTC')
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "============================================"
echo "  PropFirmBot Status Report"
echo "  $NOW"
echo "============================================"

# 1. MT5 Process
echo ""
echo ">>> MT5 PROCESS <<<"
MT5_PROC=$(ps aux | grep -i terminal64 | grep -v grep)
if [ -n "$MT5_PROC" ]; then
    echo "STATUS: RUNNING"
    echo "$MT5_PROC"
    MT5_PID=$(echo "$MT5_PROC" | awk '{print $2}')
    echo "PID: $MT5_PID"
    echo "Uptime: $(ps -o etime= -p $MT5_PID 2>/dev/null | xargs)"
    echo "Memory: $(ps -o rss= -p $MT5_PID 2>/dev/null | awk '{printf "%.0f MB", $1/1024}')"
    echo "CPU: $(ps -o %cpu= -p $MT5_PID 2>/dev/null)%"
else
    echo "STATUS: NOT RUNNING !!!"
fi

# 2. VNC
echo ""
echo ">>> VNC STATUS <<<"
XVFB=$(ps aux | grep Xvfb | grep -v grep)
X11VNC=$(ps aux | grep x11vnc | grep -v grep)
if [ -n "$XVFB" ]; then
    echo "Xvfb: RUNNING"
else
    echo "Xvfb: NOT RUNNING"
fi
if [ -n "$X11VNC" ]; then
    echo "x11vnc: RUNNING"
else
    echo "x11vnc: NOT RUNNING"
fi

# 3. EA Files
echo ""
echo ">>> EA FILES <<<"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
if [ -d "$EA_DIR" ]; then
    echo "EA directory exists"
    ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null && echo "Compiled EA: OK" || echo "Compiled EA: MISSING!"
    echo "Total files: $(ls "$EA_DIR" 2>/dev/null | wc -l)"
else
    echo "EA directory: MISSING!"
fi

# 4. Config Files
echo ""
echo ">>> CONFIG FILES <<<"
CFG_DIR="$MT5/MQL5/Files/PropFirmBot"
if [ -d "$CFG_DIR" ]; then
    ls -la "$CFG_DIR/"*.json 2>/dev/null || echo "No JSON configs found"
else
    echo "Config directory: MISSING!"
fi

# 5. Terminal Logs (today)
echo ""
echo ">>> MT5 TERMINAL LOG (today) <<<"
TERM_LOG="$MT5/logs/${TODAY}.log"
if [ -f "$TERM_LOG" ]; then
    SIZE=$(stat -c%s "$TERM_LOG" 2>/dev/null)
    echo "Log size: $SIZE bytes"
    echo "--- Last 30 lines ---"
    cat "$TERM_LOG" | tr -d '\0' | tail -30
else
    echo "No terminal log for today ($TODAY)"
    echo "Latest terminal logs:"
    ls -lt "$MT5/logs/"*.log 2>/dev/null | head -5
fi

# 6. EA Logs (today)
echo ""
echo ">>> EA LOG (today) <<<"
EA_LOG="$MT5/MQL5/Logs/${TODAY}.log"
if [ -f "$EA_LOG" ]; then
    SIZE=$(stat -c%s "$EA_LOG" 2>/dev/null)
    echo "EA Log size: $SIZE bytes"
    LINES=$(cat "$EA_LOG" | tr -d '\0' | wc -l)
    echo "Total lines: $LINES"
    echo "--- Last 40 lines ---"
    cat "$EA_LOG" | tr -d '\0' | tail -40
else
    echo "No EA log for today ($TODAY)"
    echo "Latest EA logs:"
    ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -5
    LATEST_EA=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_EA" ]; then
        echo ""
        echo "--- Last EA log: $(basename $LATEST_EA) ---"
        cat "$LATEST_EA" | tr -d '\0' | tail -20
    fi
fi

# 7. Network Connections
echo ""
echo ">>> NETWORK CONNECTIONS <<<"
echo "Outbound connections (non-SSH/VNC):"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -15
echo ""
echo "DNS resolution:"
nslookup google.com 2>/dev/null | tail -3 || echo "DNS check failed"

# 8. Account / Trade Info from logs
echo ""
echo ">>> TRADE ACTIVITY <<<"
if [ -f "$EA_LOG" ]; then
    echo "PropFirmBot mentions:"
    cat "$EA_LOG" | tr -d '\0' | grep -i "propfirmbot\|trade\|order\|position\|signal\|guardian\|drawdown\|equity\|balance" | tail -20
else
    echo "No EA log to check"
fi

# 9. Watchdog Status
echo ""
echo ">>> WATCHDOG <<<"
if crontab -l 2>/dev/null | grep -q watchdog; then
    echo "Watchdog cron: INSTALLED"
    crontab -l 2>/dev/null | grep watchdog
else
    echo "Watchdog cron: NOT INSTALLED"
fi
if systemctl is-active mt5 >/dev/null 2>&1; then
    echo "MT5 service: ACTIVE"
else
    echo "MT5 service: NOT configured as systemd service"
fi

# 10. System Health
echo ""
echo ">>> SYSTEM HEALTH <<<"
echo "Uptime: $(uptime)"
echo ""
echo "Memory:"
free -h | head -2
echo ""
echo "Disk:"
df -h / | tail -1
echo ""
echo "Load avg: $(cat /proc/loadavg)"

# 11. Wine
echo ""
echo ">>> WINE <<<"
wine --version 2>/dev/null || echo "Wine not found"

echo ""
echo "============================================"
echo "  Report Complete - $NOW"
echo "============================================"
