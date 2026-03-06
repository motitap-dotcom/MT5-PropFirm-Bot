#!/bin/bash
# Check: is MT5 running? Is EA loaded? Enable AutoTrading if needed
echo "=== CHECK+FIX $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "[1] Processes:"
ps aux | grep -i "wine\|terminal\|start.exe" | grep -v grep | head -5

echo "[2] Screen:"
screen -ls 2>/dev/null

echo "[3] Windows:"
xdotool search --name "FundedNext" 2>/dev/null | while read w; do
    echo "  $w: $(xdotool getwindowname "$w" 2>/dev/null)"
done

echo "[4] EA log:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep -i "INIT\|ALL SYSTEMS\|automated trading" | tail -8

echo "[5] Latest entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -10

echo "[6] Is AutoTrading enabled?"
LAST_AT=$(cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -1)
echo "  $LAST_AT"
if echo "$LAST_AT" | grep -q "disabled"; then
    echo "  AutoTrading is DISABLED - fixing..."
    wine "C:\\at_keybd.exe" 2>&1
    sleep 5
    echo "  After fix:"
    cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3
fi

echo "=== DONE $(date -u) ==="
