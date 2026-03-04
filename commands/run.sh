#!/bin/bash
# Check MT5 process more thoroughly - 2026-03-04
echo "=== MT5 Process Check - $(date) ==="
echo "--- All wine/terminal processes ---"
ps aux | grep -iE "wine|terminal|mt5|metatrader" | grep -v grep
echo "--- Xvfb ---"
pgrep -a Xvfb || echo "No Xvfb"
echo "--- x11vnc ---"
pgrep -a x11vnc || echo "No VNC"
echo ""
echo "--- If MT5 not running, start it ---"
if ! ps aux | grep -q "[t]erminal64"; then
    echo "MT5 not found - starting..."
    export DISPLAY=:99
    if ! pgrep -x Xvfb > /dev/null; then
        Xvfb :99 -screen 0 1280x1024x24 &
        sleep 2
    fi
    if ! pgrep -x x11vnc > /dev/null; then
        x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    fi
    cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
    WINEPREFIX=/root/.wine DISPLAY=:99 wine terminal64.exe /portable &
    sleep 15
    echo "--- After start ---"
    ps aux | grep -iE "wine|terminal" | grep -v grep
else
    echo "MT5 is already running!"
fi
echo "=== Done ==="
