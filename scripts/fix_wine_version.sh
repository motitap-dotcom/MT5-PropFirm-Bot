#!/bin/bash
# Fix Wine: remove old 9.0, ensure 11.0 is used
echo "=== FIX WINE VERSION $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# STEP 1: Stop everything
echo "--- 1. Stop MT5 ---"
pkill -9 -f "wine\|terminal64\|wineserver\|winedevice\|start.exe" 2>/dev/null
sleep 3
echo "Stopped"

# STEP 2: Check all wine binaries
echo ""
echo "--- 2. Wine binaries ---"
echo "which wine: $(which wine 2>/dev/null)"
echo "which wine64: $(which wine64 2>/dev/null)"
echo "which wine-stable: $(which wine-stable 2>/dev/null)"
echo ""
echo "wine version: $(wine --version 2>/dev/null)"
echo "wine64 version: $(wine64 --version 2>/dev/null)"
echo ""
echo "/usr/bin/wine: $(file /usr/bin/wine 2>/dev/null)"
echo "/usr/bin/wine64: $(file /usr/bin/wine64 2>/dev/null)"
echo ""
echo "Wine files:"
ls -la /usr/bin/wine* 2>/dev/null
ls -la /opt/wine-stable/bin/wine* 2>/dev/null

# STEP 3: Remove old Ubuntu wine 9.0 packages
echo ""
echo "--- 3. Remove old Wine 9.0 ---"
DEBIAN_FRONTEND=noninteractive apt-get remove -y wine wine64 wine32 libwine:amd64 libwine:i386 fonts-wine 2>&1 | tail -10
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y 2>&1 | tail -5

# STEP 4: Verify only Wine 11 remains
echo ""
echo "--- 4. Verify Wine 11 ---"
echo "wine version: $(wine --version 2>/dev/null)"
echo "wine64 version: $(wine64 --version 2>/dev/null)"
echo "which wine: $(which wine 2>/dev/null)"
echo "which wine64: $(which wine64 2>/dev/null)"
dpkg -l | grep wine | head -10

# If wine command not found, create symlinks
if ! command -v wine &>/dev/null; then
    echo "wine not in PATH, checking wine-stable..."
    if [ -f /opt/wine-stable/bin/wine ]; then
        echo "Using /opt/wine-stable/bin/wine"
        ln -sf /opt/wine-stable/bin/wine /usr/local/bin/wine
        ln -sf /opt/wine-stable/bin/wine64 /usr/local/bin/wine64
        ln -sf /opt/wine-stable/bin/wineserver /usr/local/bin/wineserver
        ln -sf /opt/wine-stable/bin/wineboot /usr/local/bin/wineboot
    fi
fi

echo ""
echo "Final wine version: $(wine --version 2>/dev/null)"

# STEP 5: Update Wine prefix
echo ""
echo "--- 5. Update Wine prefix ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine
wineboot -u 2>&1 | tail -5
echo "Prefix updated"

# STEP 6: Start MT5
echo ""
echo "--- 6. Start MT5 ---"
# Ensure display
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi
if ! pgrep -x x11vnc > /dev/null 2>&1; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
fi

cd "$MT5"
nohup wine terminal64.exe /login:11797849 /password:"gazDE62##" /server:FundedNext-Server > /tmp/mt5_wine11.log 2>&1 &
disown
echo "MT5 started"

# STEP 7: Wait and verify
echo ""
echo "--- 7. Wait 40 seconds ---"
sleep 40

echo "MT5 running: $(pgrep -f terminal64 > /dev/null 2>&1 && echo YES || echo NO)"

echo ""
echo "Outbound connections:"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10

echo ""
echo "Terminal log (latest):"
if [ -f "$MT5/logs/20260223.log" ]; then
    cat "$MT5/logs/20260223.log" | tr -d '\0' | tail -15
fi

echo ""
echo "EA log:"
if [ -f "$MT5/MQL5/Logs/20260223.log" ]; then
    echo "EXISTS!"
    cat "$MT5/MQL5/Logs/20260223.log" | tr -d '\0' | tail -15
else
    echo "Not yet"
fi

echo ""
echo "Wine log errors (non-toolbar):"
grep -v "toolbar\|^$" /tmp/mt5_wine11.log 2>/dev/null | tail -20

# Telegram
curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=🍷 Wine fix: $(wine --version 2>/dev/null)
MT5: $(pgrep -f terminal64 > /dev/null 2>&1 && echo RUNNING || echo DOWN)
Connections: $(ss -tn state established 2>/dev/null | grep -v ':22 \|:5900 \|:53 ' | wc -l)" > /dev/null 2>&1

echo ""
echo "=== DONE ==="
