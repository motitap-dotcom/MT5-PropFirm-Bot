#!/bin/bash
# =============================================================
# FIX: Kill all MT5 instances and restart with AutoTrading ON (retry)
# =============================================================

echo "============================================"
echo "  RESTART MT5 WITH AUTOTRADING"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Show current MT5 processes
echo "=== [1] Current MT5 processes ==="
ps aux | grep -i "terminal64\|metatrader" | grep -v grep
echo ""

# 2. Kill ALL MT5 processes
echo "=== [2] Killing all MT5 instances ==="
pkill -f "terminal64" 2>&1
sleep 3
# Make sure they're dead
pkill -9 -f "terminal64" 2>/dev/null
sleep 2
echo "Killed. Checking..."
ps aux | grep -i "terminal64" | grep -v grep
if [ $? -ne 0 ]; then
    echo "All MT5 processes killed successfully"
else
    echo "WARNING: Some processes still running"
fi
echo ""

# 3. Ensure config has AutoTrading enabled
echo "=== [3] Verify config ==="
COMMON_INI="/root/.wine/drive_c/Program Files/MetaTrader 5/config/common.ini"
cat "$COMMON_INI"
echo ""

# Also update startup.ini to force autotrading
STARTUP_INI="/root/.wine/drive_c/Program Files/MetaTrader 5/config/startup.ini"
if [ -f "$STARTUP_INI" ]; then
    echo "--- startup.ini ---"
    cat "$STARTUP_INI"
fi
echo ""

# 4. Start MT5 with autotrading flag
echo "=== [4] Starting MT5 ==="
cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
DISPLAY=:99 wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server /autotrading &
MT5_PID=$!
echo "Started MT5 with PID: $MT5_PID"
echo "Waiting 15 seconds for MT5 to initialize..."
sleep 15
echo ""

# 5. Check it's running
echo "=== [5] Verify MT5 running ==="
ps aux | grep -i "terminal64" | grep -v grep
echo ""

# 6. Check logs for AutoTrading status
echo "=== [6] Check logs ==="
LOG_FILE="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs/20260306.log"
echo "Last 30 log lines:"
tail -30 "$LOG_FILE" 2>/dev/null
echo ""

# 7. Also check terminal log
echo "=== [7] Terminal log ==="
TERM_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
LATEST_TERM_LOG=$(ls -t "$TERM_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_TERM_LOG" ]; then
    echo "File: $LATEST_TERM_LOG"
    tail -30 "$LATEST_TERM_LOG"
fi
echo ""

echo "============================================"
echo "  RESTART COMPLETE $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
