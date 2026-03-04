#!/bin/bash
# Delete old state file + restart EA - 2026-03-04 v2
echo "=== Fix MaxPositions - $(date) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "--- Delete old AccountState.dat ---"
STATE_FILE="$MT5/MQL5/Files/PropFirmBot/PropFirmBot_AccountState.dat"
if [ -f "$STATE_FILE" ]; then
    ls -la "$STATE_FILE"
    rm -f "$STATE_FILE"
    echo "DELETED AccountState.dat"
else
    echo "AccountState.dat not found (already deleted?)"
fi

echo ""
echo "--- Current .ex5 info ---"
ls -la "$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null

echo ""
echo "--- Restarting MT5 to reload EA with new settings ---"
# Kill MT5
pkill -f terminal64 2>/dev/null
sleep 3

# Verify killed
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "WARNING: MT5 still running, force kill"
    pkill -9 -f terminal64 2>/dev/null
    sleep 2
fi

# Start MT5
export DISPLAY=:99
cd "$MT5"
wine terminal64.exe /portable &
sleep 10

echo ""
echo "--- MT5 running? ---"
ps aux | grep "[t]erminal64" | head -2

echo ""
echo "--- EA log (last 15 lines) ---"
LATEST=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
[ -n "$LATEST" ] && cat "$LATEST" | tr -d '\0' | tail -15

echo ""
echo "--- Status JSON ---"
cat "$MT5/MQL5/Files/PropFirmBot/status.json" 2>/dev/null | tr -d '\0'

echo ""
echo "--- AccountState.dat exists? ---"
ls -la "$STATE_FILE" 2>/dev/null || echo "No AccountState.dat (will use code defaults)"

echo "=== Done ==="
