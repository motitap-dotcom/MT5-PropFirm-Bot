#!/bin/bash
# Quick verify: is new code running?
echo "=== QUICK VERIFY $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# MT5 running?
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5: RUNNING"
else
    echo "MT5: NOT RUNNING!"
fi

# EX5 timestamp
echo ""
echo "EX5 timestamp:"
ls -la "$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null

# Latest log - last 20 lines (should show NEW init with DD_Mode)
echo ""
echo "--- Latest log (last 20 lines) ---"
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" | tr -d '\0' | tail -20
fi

# status.json
echo ""
echo "--- status.json ---"
cat "$MT5/MQL5/Files/PropFirmBot/status.json" 2>/dev/null || echo "not found"

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
