#!/bin/bash
# Force MT5 to use Wine 11.0 - kill ALL old processes, rebuild prefix
echo "=== FORCE WINE 11 $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Find Wine 11 binaries
echo "--- 1. Locate Wine 11 ---"
find / -name "wine64" -type f 2>/dev/null | head -5
find / -name "wineserver" -type f 2>/dev/null | head -5
find / -name "wineboot" -type f 2>/dev/null | head -5
echo ""
ls -la /opt/wine-stable/bin/ 2>/dev/null | head -10
echo ""
# Check what wine command actually runs
file "$(which wine 2>/dev/null)" 2>/dev/null
readlink -f "$(which wine 2>/dev/null)" 2>/dev/null

# 2. KILL EVERYTHING - by PID this time
echo ""
echo "--- 2. Kill ALL Wine/MT5 (by PID) ---"
for pid in $(pgrep -f "wine\|terminal64\|start.exe\|wineserver\|winedevice"); do
    echo "Killing PID $pid: $(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')"
    kill -9 $pid 2>/dev/null
done
sleep 5

# Verify nothing is left
echo ""
remaining=$(pgrep -f "wine\|terminal64\|start.exe\|wineserver\|winedevice" 2>/dev/null | wc -l)
echo "Remaining wine processes: $remaining"
if [ "$remaining" -gt 0 ]; then
    echo "FORCE KILLING REMAINING..."
    pgrep -f "wine\|terminal64\|start.exe\|wineserver\|winedevice" | xargs -r kill -9 2>/dev/null
    sleep 3
fi

# 3. Clean ALL wine temp files
echo ""
echo "--- 3. Clean Wine temp ---"
rm -rf /tmp/.wine-* /tmp/wine-* 2>/dev/null
rm -rf /run/user/*/wine* 2>/dev/null
echo "Cleaned"

# 4. Set up correct Wine 11 PATH
echo ""
echo "--- 4. Set Wine 11 PATH ---"
WINE11_BIN=""
if [ -f /opt/wine-stable/bin/wine64 ]; then
    WINE11_BIN="/opt/wine-stable/bin"
elif [ -f /usr/bin/wine64 ]; then
    WINE11_BIN="/usr/bin"
elif [ -f /usr/local/bin/wine64 ]; then
    WINE11_BIN="/usr/local/bin"
fi

# If wine64 not found, create symlink from wine
if [ -z "$WINE11_BIN" ]; then
    echo "wine64 not found! Creating from wine..."
    WINE_PATH=$(which wine 2>/dev/null)
    if [ -n "$WINE_PATH" ]; then
        WINE_DIR=$(dirname "$WINE_PATH")
        # Wine 11 unified binary handles both 32 and 64 bit
        ln -sf "$WINE_PATH" "$WINE_DIR/wine64" 2>/dev/null
        WINE11_BIN="$WINE_DIR"
    fi
fi

echo "Wine 11 bin: $WINE11_BIN"
export PATH="$WINE11_BIN:$PATH"
echo "wine: $(wine --version 2>/dev/null)"
echo "wine64: $(wine64 --version 2>/dev/null || echo 'N/A')"

# 5. Update Wine prefix with Wine 11
echo ""
echo "--- 5. Update prefix ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Ensure Xvfb
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi

# Run wineboot to update prefix to Wine 11
timeout 30 wineboot -u 2>&1 | tail -10
sleep 5
echo "Prefix updated"

# Check what wineserver is now running
echo ""
echo "New wineserver:"
pgrep -la wineserver

# 6. Kill wineboot processes (keep wineserver)
pkill -f wineboot 2>/dev/null
sleep 2

# 7. Start VNC
if ! pgrep -x x11vnc > /dev/null 2>&1; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
fi

# 8. Start MT5
echo ""
echo "--- 6. Start MT5 ---"
cd "$MT5"
nohup wine terminal64.exe /login:11797849 /password:"gazDE62##" /server:FundedNext-Server > /tmp/mt5_wine11_final.log 2>&1 &
disown
echo "MT5 started"

# 9. Wait and check
echo ""
echo "--- 7. Wait 45 seconds ---"
sleep 45

echo "MT5 running: $(pgrep -f terminal64 > /dev/null 2>&1 && echo YES || echo NO)"
echo ""
echo "Wine server version:"
pgrep -la wineserver
echo ""
echo "Outbound connections:"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10
echo ""
echo "Terminal log (last 15):"
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
echo "Wine log (non-toolbar errors):"
grep -v "toolbar\|^$" /tmp/mt5_wine11_final.log 2>/dev/null | head -20

# Telegram
curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=🔧 Final Wine fix $(date '+%H:%M UTC')
Wine: $(wine --version 2>/dev/null)
MT5: $(pgrep -f terminal64 > /dev/null 2>&1 && echo RUNNING || echo DOWN)" > /dev/null 2>&1

echo ""
echo "=== DONE ==="
