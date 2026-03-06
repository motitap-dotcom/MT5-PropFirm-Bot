#!/bin/bash
# Deep debug - why no trades at all?
export DISPLAY=:99
export WINEPREFIX=/root/.wine

EA_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Logs"
TERM_LOG_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5/Logs"

echo "=== TIME: $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

echo ""
echo "=== FULL EA Log today ==="
cat "$EA_LOG_DIR/20260306.log" 2>/dev/null

echo ""
echo "=== EA Logs from yesterday ==="
cat "$EA_LOG_DIR/20260305.log" 2>/dev/null | tail -100

echo ""
echo "=== Terminal Log (last 50 lines) ==="
TERM_LOG=$(ls -t "$TERM_LOG_DIR/"*.log 2>/dev/null | head -1)
if [ -n "$TERM_LOG" ]; then
    echo "File: $TERM_LOG"
    tail -50 "$TERM_LOG"
fi

echo ""
echo "=== Check if EA is actually attached to chart ==="
# Look for chart config
find "/root/.wine/drive_c/Program Files/MetaTrader 5/Profiles" -name "*.chr" 2>/dev/null | while read f; do
    echo "--- Chart file: $f ---"
    grep -A5 -i "expert\|propfirm" "$f" 2>/dev/null
done

echo ""
echo "=== Check EA .ex5 exists ==="
ls -la "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot/" 2>/dev/null

echo ""
echo "=== Account info from terminal log ==="
grep -i "account\|balance\|equity\|login\|authorized" "$TERM_LOG" 2>/dev/null | tail -20

echo ""
echo "=== Any errors at all? ==="
grep -i "error\|fail\|cannot\|denied\|invalid\|wrong" "$EA_LOG_DIR/20260306.log" 2>/dev/null
grep -i "error\|fail\|cannot\|denied\|invalid\|wrong" "$TERM_LOG" 2>/dev/null | tail -20

echo ""
echo "=== Signal-related logs ==="
grep -i "signal\|scan\|smc\|liq\|sweep\|order.block\|fvg\|setup\|entry\|skip\|reject\|no.*valid" "$EA_LOG_DIR/20260306.log" 2>/dev/null

echo ""
echo "DONE $(date)"
