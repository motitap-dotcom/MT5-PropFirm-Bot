#!/bin/bash
###############################################
# PASTE THIS ENTIRE BLOCK INTO SSH TERMINAL
###############################################
echo "=== FULL RESET $(date) ==="

# 1. Kill everything
pkill -9 -f "wine\|terminal64\|wineserver\|winedevice\|start.exe"
sleep 5
rm -rf /tmp/.wine-* /tmp/wine-*

# 2. Remove Wine 11 (broken), restore Wine 9.0
echo "Removing Wine 11..."
DEBIAN_FRONTEND=noninteractive apt-get remove -y winehq-stable wine-stable wine-stable-amd64 wine-stable-i386 2>/dev/null
echo "Installing Wine 9.0..."
DEBIAN_FRONTEND=noninteractive apt-get install -y wine wine64 2>/dev/null
echo "Wine version: $(wine --version)"

# 3. Reset Wine prefix (keep MT5 files)
export DISPLAY=:99
export WINEPREFIX=/root/.wine
wineboot -u 2>/dev/null
sleep 5

# 4. Ensure display
if ! pgrep -x Xvfb > /dev/null; then Xvfb :99 -screen 0 1280x1024x24 & sleep 2; fi
if ! pgrep -x x11vnc > /dev/null; then x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null; fi

# 5. Start MT5
cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
nohup wine terminal64.exe /login:11797849 /password:"gazDE62##" /server:FundedNext-Server > /tmp/mt5.log 2>&1 &
disown

echo ""
echo "=== MT5 STARTED ==="
echo "Wait 2 minutes, then check VNC (RealVNC -> 77.237.234.2:5900)"
echo "You should see MT5 window with FundedNext account connected"
echo ""
echo "After 5 min, check terminal log:"
echo "cat '/root/.wine/drive_c/Program Files/MetaTrader 5/logs/20260223.log' | tr -d '\\0' | tail -20"
