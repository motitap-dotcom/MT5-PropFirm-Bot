#!/bin/bash
# =============================================================
# Start MT5 properly with nohup so it survives SSH disconnect
# =============================================================

echo "=== Start MT5 $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
echo ""

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Ensure VNC/display is running
export DISPLAY=:99
if ! pgrep -f "Xvfb :99" > /dev/null 2>&1; then
    echo "Starting Xvfb..."
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi
if ! pgrep -f x11vnc > /dev/null 2>&1; then
    echo "Starting x11vnc..."
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    sleep 1
fi

# Start MT5 with nohup so it survives SSH disconnect
echo "Starting MT5 with nohup..."
export WINEPREFIX=/root/.wine
cd "${MT5_BASE}"
nohup wine terminal64.exe > /dev/null 2>&1 &
disown
sleep 20

# Verify
echo ""
echo "MT5 Process:"
pgrep -f terminal64.exe > /dev/null 2>&1 && echo "OK - MT5 RUNNING (PID: $(pgrep -f terminal64.exe | head -1))" || echo "ERROR - MT5 not running"

echo ""
echo ".ex5 file:"
ls -la "${MT5_BASE}/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null

echo ""
echo "EA Log (last 15 lines):"
LATEST=$(ls -t "${MT5_BASE}/MQL5/Logs/"*.log 2>/dev/null | head -1)
[ -n "$LATEST" ] && tail -15 "$LATEST" 2>/dev/null

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
