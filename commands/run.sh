#!/bin/bash
# Start MT5 fresh + single keybd_event toggle
echo "=== RESTART+ENABLE $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Kill everything
screen -X -S mt5 quit 2>/dev/null
pkill -9 -f "start.exe\|terminal64" 2>/dev/null
sleep 3

# Start MT5 in screen
cd "$MT5"
screen -dmS mt5 bash -c 'export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1'
echo "MT5 started in screen"
sleep 20

# Verify it's running
echo "[1] Process:"
pgrep -a "start.exe\|terminal64" 2>/dev/null | head -2 || echo "NOT RUNNING"

# Run ONLY at_keybd.exe (single keybd_event Ctrl+E)
echo "[2] Enabling AutoTrading (at_keybd.exe)..."
wine "C:\\at_keybd.exe" 2>&1

# Wait and check
sleep 5
echo "[3] AutoTrading log:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3
echo "[4] Last entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -5

echo "=== DONE $(date -u) ==="
