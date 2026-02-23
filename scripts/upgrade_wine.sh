#!/bin/bash
# Upgrade Wine from 9.0 to 10.x (required by MT5)
echo "=== WINE UPGRADE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# STEP 1: Stop MT5
echo "--- 1. Stop MT5 ---"
pkill -f terminal64 2>/dev/null
sleep 2
pkill -9 -f "wine\|terminal64\|wineserver\|winedevice\|start.exe" 2>/dev/null
sleep 2
echo "Stopped"

# STEP 2: Check current Wine version
echo ""
echo "--- 2. Current Wine ---"
wine --version 2>/dev/null || echo "wine not in path"
/opt/wine-stable/bin/wine --version 2>/dev/null || echo "opt wine-stable not found"
/usr/bin/wine --version 2>/dev/null || echo "/usr/bin/wine not found"
dpkg -l | grep wine | head -10

# STEP 3: Add WineHQ repository for latest stable
echo ""
echo "--- 3. Add WineHQ repo ---"
dpkg --add-architecture i386 2>/dev/null

# Get Ubuntu version
UBUNTU_VER=$(lsb_release -cs 2>/dev/null || echo "jammy")
echo "Ubuntu: $UBUNTU_VER"

# Add WineHQ key and repo
mkdir -p /etc/apt/keyrings
wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key 2>&1
wget -qNP /etc/apt/sources.list.d/ "https://dl.winehq.org/wine-builds/ubuntu/dists/${UBUNTU_VER}/winehq-${UBUNTU_VER}.sources" 2>&1 || true

# Alternative: direct repo line
echo "deb [signed-by=/etc/apt/keyrings/winehq-archive.key] https://dl.winehq.org/wine-builds/ubuntu/ $UBUNTU_VER main" > /etc/apt/sources.list.d/winehq.list 2>/dev/null

echo "Repo added"

# STEP 4: Update and install Wine stable
echo ""
echo "--- 4. Install Wine ---"
apt-get update -qq 2>&1 | tail -5

# Try installing latest wine-stable
echo "Installing winehq-stable..."
DEBIAN_FRONTEND=noninteractive apt-get install -y --install-recommends winehq-stable 2>&1 | tail -20

# Check result
echo ""
echo "--- 5. Verify new Wine ---"
wine --version 2>/dev/null
wine64 --version 2>/dev/null
echo "Wine binary: $(which wine 2>/dev/null)"

# STEP 6: If Wine 10 installed, restart MT5
WINE_VER=$(wine --version 2>/dev/null)
echo "Wine version: $WINE_VER"

echo ""
echo "--- 6. Restart MT5 with new Wine ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Ensure display
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi
if ! pgrep -x x11vnc > /dev/null 2>&1; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
fi

cd "$MT5"
nohup wine terminal64.exe /login:11797849 /password:"gazDE62##" /server:FundedNext-Server > /tmp/mt5_wine_new.log 2>&1 &
disown
echo "MT5 started"

# STEP 7: Wait and check
echo ""
echo "--- 7. Wait 30 seconds... ---"
sleep 30

echo "MT5 running: $(pgrep -f terminal64 > /dev/null 2>&1 && echo YES || echo NO)"
echo ""
echo "Wine version running:"
wine --version 2>/dev/null

echo ""
echo "Outbound connections:"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10

echo ""
echo "Terminal log (last 15 lines):"
if [ -f "$MT5/logs/20260223.log" ]; then
    cat "$MT5/logs/20260223.log" | tr -d '\0' | tail -15
fi

echo ""
echo "EA log:"
if [ -f "$MT5/MQL5/Logs/20260223.log" ]; then
    echo "EXISTS!"
    cat "$MT5/MQL5/Logs/20260223.log" | tr -d '\0' | tail -15
else
    echo "Not yet (waiting for symbol sync...)"
fi

# STEP 8: Telegram
curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=🍷 Wine upgraded: $WINE_VER
MT5: $(pgrep -f terminal64 > /dev/null 2>&1 && echo RUNNING || echo DOWN)
Connections: $(ss -tn state established 2>/dev/null | grep -v ':22 \|:5900 \|:53 ' | wc -l)" > /dev/null 2>&1

echo ""
echo "=== DONE ==="
