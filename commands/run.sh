#!/bin/bash
# Verify AutoTrading is working after fix
echo "=== VERIFY AutoTrading FIX $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Is MT5 running?
echo "[1] MT5 process:"
pgrep -fa terminal64 || echo "NOT RUNNING!"
echo ""

# 2. Check EA log for errors or successful trades
echo "[2] Last 40 lines of EA log:"
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "File: $LATEST_LOG"
    tail -40 "$LATEST_LOG" 2>&1
else
    echo "No logs found"
fi
echo ""

# 3. Check terminal log
echo "[3] Terminal log (last 20 lines):"
TLOG=$(ls -t "$MT5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$TLOG" ]; then
    echo "File: $TLOG"
    tail -20 "$TLOG" 2>&1
fi
echo ""

# 4. Account status
echo "[4] mt5_status.json:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null || cat /var/bots/mt5_status.json 2>/dev/null || echo "NOT FOUND"
echo ""

# 5. Check config values
echo "[5] AutoTrading in terminal.ini:"
grep -i "autotrad\|ExpertEnable" "$MT5/terminal.ini" 2>/dev/null || echo "(none)"
echo ""

echo "=== DONE $(date -u) ==="
