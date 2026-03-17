#!/bin/bash
# Post-deploy verification check - 2026-03-17
echo "=== POST-DEPLOY VERIFICATION $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. MT5 process alive?
echo "--- 1. MT5 Process ---"
if pgrep -f terminal64 > /dev/null 2>&1; then
    PID=$(pgrep -f terminal64 | head -1)
    UPTIME=$(ps -o etime= -p $PID 2>/dev/null | xargs)
    echo "MT5: RUNNING (PID=$PID, uptime=$UPTIME)"
else
    echo "MT5: NOT RUNNING!"
fi

# 2. EX5 compile timestamp
echo ""
echo "--- 2. EX5 File (latest compile) ---"
ls -la "$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null

# 3. EA log - last 30 lines (check for errors after deploy)
echo ""
echo "--- 3. EA Log (last 30 lines) ---"
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Log file: $LATEST_LOG"
    cat "$LATEST_LOG" | tr -d '\0' | tail -30
else
    echo "No log files found"
fi

# 4. Any compile errors?
echo ""
echo "--- 4. Compile Errors ---"
if [ -n "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" | tr -d '\0' | grep -iE "compile|syntax|error.*mqh|error.*mq5" | tail -10
    echo "(empty = no compile errors)"
fi

# 5. status.json (EA writing status = alive)
echo ""
echo "--- 5. status.json ---"
cat "$MT5/MQL5/Files/PropFirmBot/status.json" 2>/dev/null || echo "NOT FOUND"

# 6. Guardian state
echo ""
echo "--- 6. Guardian State ---"
if [ -n "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" | tr -d '\0' | grep -E "GUARDIAN|HEARTBEAT" | tail -5
fi

# 7. Recent errors/warnings
echo ""
echo "--- 7. Errors Since Deploy ---"
if [ -n "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" | tr -d '\0' | grep -iE "error|fail|crash|critical|FATAL" | tail -10
    ERRCOUNT=$(cat "$LATEST_LOG" | tr -d '\0' | grep -ciE "error|fail|crash|critical|FATAL" 2>/dev/null)
    echo "Total error lines: $ERRCOUNT"
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
