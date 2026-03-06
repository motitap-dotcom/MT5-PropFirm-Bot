#!/bin/bash
# =============================================================
# Full status check: Was the latest update deployed? Is bot working?
# =============================================================

echo "============================================"
echo "  FULL BOT STATUS CHECK"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# 1. Check git status on VPS - was latest code pulled?
echo "=== [1] Git status on VPS ==="
cd /root/MT5-PropFirm-Bot
git log --oneline -5 2>&1
echo ""
echo "Current branch: $(git rev-parse --abbrev-ref HEAD 2>&1)"
echo "Last commit: $(git log -1 --format='%H %s (%ci)' 2>&1)"
echo ""

# 2. Check if EA files are up to date
echo "=== [2] EA files on disk ==="
MT5_EA="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"
echo "EA directory:"
ls -la "$MT5_EA/" 2>&1 | head -20
echo ""
echo "SignalEngine.mqh last modified:"
stat -c '%y %n' "$MT5_EA/SignalEngine.mqh" 2>&1
echo ""

# 3. Is MT5 running?
echo "=== [3] MT5 Process ==="
ps aux | grep -i "terminal64\|metatrader" | grep -v grep
MT5_PID=$(pgrep -f terminal64)
if [ -n "$MT5_PID" ]; then
    echo "MT5 is RUNNING (PID: $MT5_PID)"
else
    echo "MT5 is NOT RUNNING!"
fi
echo ""

# 4. Account status from mt5_status.json
echo "=== [4] Bot Status (mt5_status.json) ==="
if [ -f /var/bots/mt5_status.json ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null || cat /var/bots/mt5_status.json
    echo ""
    echo "File age: $(stat -c '%y' /var/bots/mt5_status.json 2>&1)"
else
    echo "mt5_status.json NOT FOUND"
fi
echo ""

# 5. Check EA logs (last 30 lines)
echo "=== [5] EA Logs (recent) ==="
EA_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
LATEST_LOG=$(ls -t "$EA_LOG_DIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Log file: $LATEST_LOG"
    tail -30 "$LATEST_LOG" 2>&1
else
    echo "No EA logs found in $EA_LOG_DIR"
    # Try terminal logs
    TERM_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
    LATEST_TLOG=$(ls -t "$TERM_LOG_DIR/"*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_TLOG" ]; then
        echo "Terminal log: $LATEST_TLOG"
        tail -30 "$LATEST_TLOG" 2>&1
    fi
fi
echo ""

# 6. Check services
echo "=== [6] Services ==="
systemctl is-active mt5.service 2>&1 && echo "mt5.service: active" || echo "mt5.service: inactive"
systemctl is-active mt5-status-daemon.service 2>&1 && echo "mt5-status-daemon: active" || echo "mt5-status-daemon: inactive"
systemctl is-active mt5-watchdog.service 2>&1 && echo "mt5-watchdog: active" || echo "mt5-watchdog: inactive"
echo ""

# 7. Check compiled EA (.ex5)
echo "=== [7] Compiled EA ==="
EX5="$MT5_EA/PropFirmBot.ex5"
if [ -f "$EX5" ]; then
    echo "PropFirmBot.ex5 EXISTS"
    stat -c 'Size: %s bytes, Modified: %y' "$EX5" 2>&1
else
    echo "PropFirmBot.ex5 NOT FOUND - EA not compiled!"
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
