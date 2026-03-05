#!/bin/bash
# =============================================================
# VPS Full Status Report - 2026-03-05
# =============================================================

echo "=============================================="
echo "  FULL VPS STATUS REPORT - $(date)"
echo "=============================================="
echo ""

# 1. System Info
echo "=== 1. SYSTEM INFO ==="
echo "Uptime: $(uptime)"
echo "Memory:"
free -h
echo ""
echo "Disk:"
df -h /
echo ""

# 2. MT5 Process
echo "=== 2. MT5 PROCESS ==="
if pgrep -a terminal64; then
    echo "STATUS: MT5 IS RUNNING"
else
    echo "STATUS: MT5 IS NOT RUNNING!"
fi
if pgrep -a metatrader; then
    echo "(metatrader process found)"
fi
echo ""

# 3. Wine processes
echo "=== 3. WINE PROCESSES ==="
pgrep -a wine 2>/dev/null || echo "No wine processes"
pgrep -a wineserver 2>/dev/null || echo "No wineserver"
echo ""

# 4. VNC / Display
echo "=== 4. DISPLAY & VNC ==="
pgrep -a Xvfb 2>/dev/null || echo "No Xvfb"
pgrep -a x11vnc 2>/dev/null || echo "No x11vnc"
echo "DISPLAY=$DISPLAY"
echo ""

# 5. EA Files
echo "=== 5. EA FILES ==="
EA_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"
if [ -d "$EA_DIR" ]; then
    ls -la "$EA_DIR/"
    echo ""
    echo "EX5 file details:"
    ls -la "$EA_DIR/"*.ex5 2>/dev/null || echo "NO .ex5 compiled files!"
else
    echo "EA directory NOT FOUND!"
fi
echo ""

# 6. Config Files
echo "=== 6. CONFIG FILES ==="
CONFIG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot"
if [ -d "$CONFIG_DIR" ]; then
    ls -la "$CONFIG_DIR/"
else
    echo "Config directory NOT FOUND!"
fi
echo ""

# 7. MT5 Logs - Last entries
echo "=== 7. MT5 LOGS (Last 30 lines) ==="
MT5_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
if [ -d "$MT5_LOG_DIR" ]; then
    LATEST_LOG=$(ls -t "$MT5_LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -f "$LATEST_LOG" ]; then
        echo "Log file: $LATEST_LOG"
        echo "Last modified: $(stat -c '%y' "$LATEST_LOG")"
        echo "---"
        tail -30 "$LATEST_LOG"
    else
        echo "No log files found"
    fi
else
    echo "Log directory not found"
fi
echo ""

# 8. MT5 Terminal Logs
echo "=== 8. MT5 TERMINAL LOGS (Last 20 lines) ==="
TERM_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
if [ -d "$TERM_LOG_DIR" ]; then
    LATEST_TLOG=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -f "$LATEST_TLOG" ]; then
        echo "Log file: $LATEST_TLOG"
        echo "Last modified: $(stat -c '%y' "$LATEST_TLOG")"
        echo "---"
        tail -20 "$LATEST_TLOG"
    else
        echo "No terminal log files"
    fi
else
    echo "Terminal log directory not found"
fi
echo ""

# 9. Account Status (from EA status file if exists)
echo "=== 9. EA STATUS FILE ==="
STATUS_FILE="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/bot_status.json"
if [ -f "$STATUS_FILE" ]; then
    cat "$STATUS_FILE"
else
    echo "No bot_status.json found"
    # Try other status files
    find "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/" -name "*.json" -o -name "*.txt" -o -name "*.csv" 2>/dev/null | while read f; do
        echo "Found: $f ($(stat -c '%y' "$f" 2>/dev/null))"
    done
fi
echo ""

# 10. Trade Journal
echo "=== 10. TRADE JOURNAL ==="
JOURNAL_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot"
find "$JOURNAL_DIR" -name "*journal*" -o -name "*trade*" -o -name "*log*" 2>/dev/null | while read f; do
    echo "--- $f ---"
    tail -10 "$f" 2>/dev/null
    echo ""
done
echo ""

# 11. Network - Can MT5 reach broker?
echo "=== 11. NETWORK ==="
echo "Internet:"
ping -c 1 -W 3 google.com > /dev/null 2>&1 && echo "Internet: OK" || echo "Internet: FAILED"
echo ""

# 12. Cron jobs
echo "=== 12. SCHEDULED TASKS ==="
crontab -l 2>/dev/null || echo "No crontab"
echo ""

# 13. Last reboot / crashes
echo "=== 13. RECENT EVENTS ==="
last reboot | head -5
echo ""

# 14. Repo status on VPS
echo "=== 14. REPO ON VPS ==="
if [ -d /root/MT5-PropFirm-Bot ]; then
    cd /root/MT5-PropFirm-Bot
    echo "Branch: $(git branch --show-current 2>/dev/null)"
    echo "Last commit: $(git log --oneline -1 2>/dev/null)"
    echo "Status: $(git status --short 2>/dev/null | head -5)"
else
    echo "Repo not found on VPS"
fi
echo ""

echo "=============================================="
echo "  END OF REPORT - $(date)"
echo "=============================================="
