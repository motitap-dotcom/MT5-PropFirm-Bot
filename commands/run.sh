#!/bin/bash
# Fix max positions + restart - 2026-03-04 v3
echo "=== Fix MaxPositions - $(date) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "--- Step 1: Delete AccountState.dat ---"
STATE_FILE="$MT5/MQL5/Files/PropFirmBot/PropFirmBot_AccountState.dat"
if [ -f "$STATE_FILE" ]; then
    echo "Found - deleting..."
    rm -f "$STATE_FILE"
    echo "DELETED"
else
    echo "Not found (already clean)"
fi

echo ""
echo "--- Step 2: Restart MT5 ---"
pkill -f terminal64 2>/dev/null
sleep 5
export DISPLAY=:99
cd "$MT5"
wine terminal64.exe /portable &
sleep 15

echo ""
echo "--- Step 3: Verify ---"
ps aux | grep "[t]erminal64" | head -2

echo ""
LATEST=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
echo "--- EA log (last 10 lines) ---"
[ -n "$LATEST" ] && cat "$LATEST" | tr -d '\0' | tail -10

echo "=== Done ==="
