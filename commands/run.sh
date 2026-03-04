#!/bin/bash
echo "=== Fix MaxPositions - $(date) ==="
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Step 1: Delete old state file
STATE="$MT5/MQL5/Files/PropFirmBot/PropFirmBot_AccountState.dat"
if [ -f "$STATE" ]; then
    rm -f "$STATE" && echo "AccountState.dat DELETED"
else
    echo "AccountState.dat not found (clean)"
fi

# Step 2: Restart MT5 (nohup so SSH doesnt hang)
pkill -f terminal64 2>/dev/null
sleep 3
export DISPLAY=:99
cd "$MT5"
nohup wine terminal64.exe /portable > /dev/null 2>&1 &
sleep 8

# Step 3: Quick verify
ps aux | grep "[t]erminal64" | head -1 && echo "MT5 RUNNING" || echo "MT5 NOT RUNNING"
echo "=== Done ==="
