#!/bin/bash
# Install official MT5 for Linux (self-contained with compatible Wine)
echo "=== INSTALL MT5 LINUX $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_OLD="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Kill all MT5/Wine
echo "--- 1. Stop everything ---"
pkill -9 -f "wine\|terminal64\|wineserver\|winedevice\|start.exe" 2>/dev/null
sleep 3
rm -rf /tmp/.wine-* /tmp/wine-* 2>/dev/null
echo "Stopped"

# 2. Ensure display
echo ""
echo "--- 2. Display ---"
export DISPLAY=:99
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi
if ! pgrep -x x11vnc > /dev/null 2>&1; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
fi
echo "Display OK"

# 3. Download official MT5 installer
echo ""
echo "--- 3. Download MT5 ---"
cd /tmp
wget -q "https://download.mql5.com/cdn/web/metaquotes.ltd/mt5/mt5setup.exe" -O mt5setup.exe 2>&1
ls -la mt5setup.exe
echo "Downloaded: $(stat -c%s mt5setup.exe 2>/dev/null) bytes"

# 4. Run installer with Wine 11
echo ""
echo "--- 4. Install MT5 ---"
export WINEPREFIX=/root/.wine
export DISPLAY=:99

# Set Wine to automatically accept dialogs
wine reg add "HKCU\\Software\\Wine" /v ShowDotFiles /t REG_SZ /d Y /f 2>/dev/null

# Run the installer - it should auto-install and launch MT5
timeout 120 wine mt5setup.exe /auto 2>/dev/null &
INSTALL_PID=$!
echo "Installer PID: $INSTALL_PID"

# Wait for installation (max 2 min)
echo "Waiting for installer (up to 2 min)..."
for i in $(seq 1 12); do
    sleep 10
    if ! kill -0 $INSTALL_PID 2>/dev/null; then
        echo "Installer finished at iteration $i"
        break
    fi
    echo "  ...still installing ($((i*10))s)"
done

# Kill installer if still running
kill $INSTALL_PID 2>/dev/null
sleep 2

# 5. Find new MT5 installation
echo ""
echo "--- 5. Find MT5 ---"
find /root/.wine/drive_c -name "terminal64.exe" -type f 2>/dev/null
echo ""
echo "MT5 directories:"
find /root/.wine/drive_c -name "MetaTrader*" -type d 2>/dev/null

# Check if new MT5 was installed
NEW_MT5=$(find /root/.wine/drive_c -name "terminal64.exe" -newer /tmp/mt5setup.exe -type f 2>/dev/null | head -1)
if [ -z "$NEW_MT5" ]; then
    # Use the existing one
    NEW_MT5="$MT5_OLD/terminal64.exe"
    echo "Using existing MT5: $NEW_MT5"
else
    echo "New MT5 found: $NEW_MT5"
fi

MT5_DIR=$(dirname "$NEW_MT5")
echo "MT5 dir: $MT5_DIR"

# 6. Copy EA files to new MT5 location (if different)
echo ""
echo "--- 6. Copy EA files ---"
if [ "$MT5_DIR" != "$MT5_OLD" ]; then
    echo "Copying to new location..."
    mkdir -p "$MT5_DIR/MQL5/Experts/PropFirmBot/"
    cp -v "$MT5_OLD/MQL5/Experts/PropFirmBot/"* "$MT5_DIR/MQL5/Experts/PropFirmBot/" 2>/dev/null
    mkdir -p "$MT5_DIR/MQL5/Files/PropFirmBot/"
    cp -v "$MT5_OLD/MQL5/Files/PropFirmBot/"* "$MT5_DIR/MQL5/Files/PropFirmBot/" 2>/dev/null
else
    echo "Same location, no copy needed"
fi

# 7. Kill any MT5 that auto-started from installer, then start fresh
echo ""
echo "--- 7. Start MT5 fresh ---"
pkill -f terminal64 2>/dev/null
sleep 3

cd "$MT5_DIR"
nohup wine "$NEW_MT5" /login:11797849 /password:"gazDE62##" /server:FundedNext-Server > /tmp/mt5_final.log 2>&1 &
disown
echo "MT5 started from: $MT5_DIR"

# 8. Wait and check
echo ""
echo "--- 8. Wait 30 seconds ---"
sleep 30

echo "MT5 running: $(pgrep -f terminal64 > /dev/null 2>&1 && echo YES || echo NO)"
echo ""
echo "Outbound connections:"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -10
echo ""
echo "Terminal log:"
LATEST=$(ls -t "$MT5_DIR/logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    cat "$LATEST" | tr -d '\0' | tail -15
fi
echo ""
echo "EA log:"
EALOG=$(ls -t "$MT5_DIR/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$EALOG" ]; then
    echo "EXISTS!"
    cat "$EALOG" | tr -d '\0' | tail -10
else
    echo "Not yet"
fi

# Telegram
curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=📦 MT5 reinstalled $(date '+%H:%M UTC')
Wine: $(wine --version 2>/dev/null)
MT5: $(pgrep -f terminal64 > /dev/null 2>&1 && echo RUNNING || echo DOWN)
Connections: $(ss -tn state established 2>/dev/null | grep -v ':22 \|:5900 \|:53 ' | wc -l)" > /dev/null 2>&1

echo ""
echo "=== DONE ==="
