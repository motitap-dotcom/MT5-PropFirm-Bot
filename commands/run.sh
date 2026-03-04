#!/bin/bash
# =============================================================
# Diagnose why EA is not trading - 2026-03-04
# =============================================================

echo "=== EA Trading Diagnosis - $(date) ==="

# 1. Check if MT5 is running
echo ""
echo "--- MT5 Process ---"
pgrep -a terminal64 || echo "MT5 NOT RUNNING!"

# 2. Check account status
echo ""
echo "--- Account Connection (Terminal Log last 30 lines) ---"
TERM_LOG="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"
LATEST_TERM=$(ls -t "$TERM_LOG"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_TERM" ]; then
    tail -30 "$LATEST_TERM" | strings
fi

# 3. Check EA log - this is where trading decisions are logged
echo ""
echo "--- EA Log Today (last 100 lines) ---"
EA_LOG="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
TODAY=$(date +%Y%m%d)
if [ -f "$EA_LOG/${TODAY}.log" ]; then
    tail -100 "$EA_LOG/${TODAY}.log" | strings
else
    echo "No EA log for today ($TODAY)"
    echo "Available EA logs:"
    ls -la "$EA_LOG"/*.log 2>/dev/null | tail -5
    LATEST_EA=$(ls -t "$EA_LOG"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_EA" ]; then
        echo ""
        echo "--- Latest EA log: $LATEST_EA (last 100 lines) ---"
        tail -100 "$LATEST_EA" | strings
    fi
fi

# 4. Check AutoTrading status
echo ""
echo "--- AutoTrading Config ---"
TERMINAL_INI="/root/.wine/drive_c/Program Files/MetaTrader 5/config/common.ini"
if [ -f "$TERMINAL_INI" ]; then
    cat "$TERMINAL_INI" | strings
else
    echo "No common.ini found"
    # Try alternate locations
    find "/root/.wine/drive_c/Program Files/MetaTrader 5/" -name "*.ini" -type f 2>/dev/null | head -10
fi

# 5. Check if EA is actually attached
echo ""
echo "--- Chart Config ---"
CHART_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Profiles"
find "$CHART_DIR" -name "*.chr" -type f 2>/dev/null | while read chr; do
    echo "Chart file: $chr"
    strings "$chr" | grep -i -A2 "expert\|propfirm\|autotrading" | head -10
done

# 6. Check trade history
echo ""
echo "--- Open Positions & Orders ---"
# Look in EA status file if exists
STATUS_FILE="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/status.json"
if [ -f "$STATUS_FILE" ]; then
    echo "Status file:"
    cat "$STATUS_FILE" | strings
fi

# 7. Check spread/signal blocks
echo ""
echo "--- Recent BLOCKED/SIGNAL messages (from EA log) ---"
LATEST_EA=$(ls -t "$EA_LOG"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_EA" ]; then
    strings "$LATEST_EA" | grep -i "BLOCK\|SIGNAL\|TRADE\|ORDER\|REJECT\|ERROR\|WARNING\|HEARTBEAT" | tail -40
fi

echo ""
echo "=== Done ==="
