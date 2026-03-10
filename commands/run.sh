#!/bin/bash
# =============================================================
# Verify EA is running with latest compiled version
# =============================================================

echo "============================================"
echo "  Verify PropFirmBot EA is LIVE"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"

# 1. Is MT5 process running?
echo "=== [1] MT5 Process ==="
if pgrep -f terminal64.exe > /dev/null 2>&1; then
    echo "OK - MT5 is RUNNING (PID: $(pgrep -f terminal64.exe))"
else
    echo "PROBLEM - MT5 is NOT running!"
fi
echo ""

# 2. Check .ex5 file timestamp - is it the new version?
echo "=== [2] Compiled EA file (.ex5) ==="
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
echo "Current time: $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

# 3. Check MT5 logs for EA activity
echo "=== [3] MT5 Logs (last 50 lines) ==="
MT5_LOGS="${MT5_BASE}/Logs"
LATEST_LOG=$(ls -t "$MT5_LOGS"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Log file: $LATEST_LOG"
    tail -50 "$LATEST_LOG" 2>/dev/null
else
    echo "No log files found in $MT5_LOGS"
fi
echo ""

# 4. Check EA-specific logs (Expert tab)
echo "=== [4] Expert Advisor Logs ==="
EA_LOGS="${MT5_BASE}/MQL5/Logs"
LATEST_EA_LOG=$(ls -t "$EA_LOGS"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_EA_LOG" ]; then
    echo "EA Log file: $LATEST_EA_LOG"
    tail -50 "$LATEST_EA_LOG" 2>/dev/null
else
    echo "No EA log files found in $EA_LOGS"
fi
echo ""

# 5. Check if there's trade activity
echo "=== [5] Account & Trade Status ==="
STATUS_FILE="${MT5_BASE}/MQL5/Files/PropFirmBot/status.json"
if [ -f "$STATUS_FILE" ]; then
    echo "Status file found:"
    cat "$STATUS_FILE" 2>/dev/null
else
    echo "No status.json found"
fi
echo ""

# 6. Check mt5_status.json from daemon
echo "=== [6] MT5 Status Daemon ==="
if [ -f /var/bots/mt5_status.json ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null || cat /var/bots/mt5_status.json
else
    echo "No mt5_status.json found"
fi
echo ""

# 7. Was EA reloaded after recompile? Check if MT5 was restarted
echo "=== [7] MT5 Process Uptime ==="
MT5_PID=$(pgrep -f terminal64.exe | head -1)
if [ -n "$MT5_PID" ]; then
    echo "MT5 PID: $MT5_PID"
    echo "Started: $(ps -o lstart= -p $MT5_PID 2>/dev/null)"
    echo "Uptime: $(ps -o etime= -p $MT5_PID 2>/dev/null)"
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
