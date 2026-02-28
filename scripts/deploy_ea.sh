#!/bin/bash
# Deploy EA files to VPS, compile, and restart MT5
echo "=== EA DEPLOYMENT $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"

echo "--- Step 1: Stop MT5 ---"
pkill -f terminal64 2>/dev/null && echo "MT5 stopped" || echo "MT5 was not running"
sleep 3

echo ""
echo "--- Step 2: Backup current EA ---"
if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    cp "$EA_DIR/PropFirmBot.ex5" "$EA_DIR/PropFirmBot.ex5.bak"
    echo "Backup created: PropFirmBot.ex5.bak"
fi

echo ""
echo "--- Step 3: Copy new EA files ---"
cp /tmp/ea_deploy/*.mq5 "$EA_DIR/" 2>/dev/null && echo "Copied .mq5 files"
cp /tmp/ea_deploy/*.mqh "$EA_DIR/" 2>/dev/null && echo "Copied .mqh files"
ls -la "$EA_DIR/"

echo ""
echo "--- Step 4: Compile EA ---"
cd "$MT5"
DISPLAY=:99 wine metaeditor64.exe /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log 2>/dev/null
sleep 5

if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    NEW_SIZE=$(stat -c%s "$EA_DIR/PropFirmBot.ex5")
    NEW_DATE=$(stat -c%y "$EA_DIR/PropFirmBot.ex5")
    echo "COMPILE SUCCESS! Size: $NEW_SIZE bytes | Date: $NEW_DATE"
else
    echo "COMPILE FAILED! ex5 not found"
    if [ -f "$EA_DIR/PropFirmBot.ex5.bak" ]; then
        cp "$EA_DIR/PropFirmBot.ex5.bak" "$EA_DIR/PropFirmBot.ex5"
        echo "Restored backup"
    fi
fi

echo ""
echo "--- Step 5: Start MT5 ---"
export DISPLAY=:99
# Make sure Xvfb is running
pgrep Xvfb > /dev/null || (Xvfb :99 -screen 0 1280x1024x24 &)
sleep 1

# Start MT5
cd "$MT5"
wine terminal64.exe /config:"$MT5/config/startup.ini" &
sleep 10

echo ""
echo "--- Step 6: Verify ---"
if pgrep -f terminal64 > /dev/null; then
    echo "MT5 IS RUNNING"
else
    echo "MT5 FAILED TO START!"
fi

# Check VNC
pgrep x11vnc > /dev/null || (x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null && echo "VNC restarted")

echo ""
echo "=== DEPLOYMENT COMPLETE ==="
