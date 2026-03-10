#!/bin/bash
# =============================================================
# FULL STATUS CHECK: MT5 + Bot + Trades
# =============================================================

echo "============================================"
echo "  FULL BOT STATUS CHECK"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# =============================================
# 1. MT5 Process
# =============================================
echo "=== 1. MT5 Process ==="
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5: RUNNING"
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    if [ -n "$MT5_PID" ]; then
        echo "PID: $MT5_PID"
        echo "Memory: $(ps -p $MT5_PID -o rss= 2>/dev/null | awk '{printf "%.0f MB", $1/1024}')"
        echo "Uptime: $(ps -p $MT5_PID -o etime= 2>/dev/null | xargs)"
        echo "CPU: $(ps -p $MT5_PID -o %cpu= 2>/dev/null | xargs)%"
    fi
else
    echo "MT5: NOT RUNNING!"
fi
echo ""

# =============================================
# 2. Memory & System
# =============================================
echo "=== 2. System Resources ==="
free -h | head -3
echo ""
echo "Disk:"
df -h / | tail -1
echo ""
echo "Load average: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

# =============================================
# 3. VNC Status
# =============================================
echo "=== 3. VNC/Display ==="
if pgrep -f x11vnc > /dev/null 2>&1; then
    echo "VNC: RUNNING"
else
    echo "VNC: NOT RUNNING"
fi
if pgrep -f Xvfb > /dev/null 2>&1; then
    echo "Xvfb: RUNNING"
else
    echo "Xvfb: NOT RUNNING"
fi
echo ""

# =============================================
# 4. MT5 Logs (last activity)
# =============================================
echo "=== 4. MT5 Recent Logs ==="
MT5_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
if [ -d "$MT5_LOG_DIR" ]; then
    LATEST_LOG=$(ls -t "$MT5_LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo "Latest log: $(basename "$LATEST_LOG")"
        echo "Last 30 lines:"
        tail -30 "$LATEST_LOG"
    else
        echo "No log files found"
    fi
else
    echo "Log directory not found"
fi
echo ""

# =============================================
# 5. EA Expert Logs
# =============================================
echo "=== 5. EA Expert Logs ==="
EA_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
if [ -d "$EA_LOG_DIR" ]; then
    LATEST_EA_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_EA_LOG" ]; then
        echo "Latest EA log: $(basename "$LATEST_EA_LOG")"
        echo "Last 40 lines:"
        tail -40 "$LATEST_EA_LOG"
    else
        echo "No EA log files found"
    fi
else
    echo "EA log directory not found"
fi
echo ""

# =============================================
# 6. PropFirmBot files
# =============================================
echo "=== 6. EA Files Status ==="
EA_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"
if [ -d "$EA_DIR" ]; then
    echo "EA directory exists"
    echo "Files:"
    ls -la "$EA_DIR/" 2>/dev/null | head -20
    echo ""
    # Check if compiled
    if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
        echo "Compiled EA: YES (PropFirmBot.ex5 exists)"
        echo "Last compiled: $(stat -c '%y' "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d. -f1)"
    else
        echo "Compiled EA: NO - .ex5 not found!"
    fi
else
    echo "EA directory NOT FOUND!"
fi
echo ""

# =============================================
# 7. Config files
# =============================================
echo "=== 7. Config Files ==="
CONFIG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot"
if [ -d "$CONFIG_DIR" ]; then
    ls -la "$CONFIG_DIR/" 2>/dev/null
else
    echo "Config directory not found"
fi
echo ""

# =============================================
# 8. Trade History (from journal)
# =============================================
echo "=== 8. Trade Journal ==="
JOURNAL_FILE="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/trade_journal.csv"
if [ -f "$JOURNAL_FILE" ]; then
    echo "Trade journal exists"
    TOTAL_TRADES=$(wc -l < "$JOURNAL_FILE" 2>/dev/null)
    echo "Total entries: $TOTAL_TRADES"
    echo "Last 10 trades:"
    tail -10 "$JOURNAL_FILE"
else
    echo "No trade journal found (no trades executed yet?)"
fi
echo ""

# =============================================
# 9. Watchdog Status
# =============================================
echo "=== 9. Watchdog ==="
if [ -f /root/mt5_watchdog.sh ]; then
    echo "Watchdog script: EXISTS"
    # Check if running via cron
    if crontab -l 2>/dev/null | grep -q "mt5_watchdog"; then
        echo "Watchdog cron: ACTIVE"
        crontab -l 2>/dev/null | grep "mt5_watchdog"
    else
        echo "Watchdog cron: NOT FOUND"
    fi
else
    echo "Watchdog: NOT INSTALLED"
fi
echo ""

# =============================================
# 10. Network connectivity
# =============================================
echo "=== 10. Network ==="
echo -n "Internet: "
if ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; then
    echo "OK"
else
    echo "NO CONNECTION"
fi
echo -n "MT5 server (FundedNext): "
if timeout 5 bash -c 'echo > /dev/tcp/77.237.234.2/443' 2>/dev/null; then
    echo "Port 443 open"
else
    echo "Cannot check directly"
fi
echo ""

# =============================================
# Summary
# =============================================
echo "============================================"
echo "  SUMMARY"
echo "============================================"
MT5_OK="NO"
pgrep -f terminal64 > /dev/null 2>&1 && MT5_OK="YES"
VNC_OK="NO"
pgrep -f x11vnc > /dev/null 2>&1 && VNC_OK="YES"

echo "  MT5 Running:     $MT5_OK"
echo "  VNC Running:     $VNC_OK"
echo "  Date:            $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
