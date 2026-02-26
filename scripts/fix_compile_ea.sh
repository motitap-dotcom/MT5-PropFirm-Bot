#!/bin/bash
# Fix EA compilation on VPS after Wine Staging upgrade
# This script ensures PropFirmBot EA is compiled and running

echo "========================================="
echo "  PropFirmBot EA Fix & Compile Script"
echo "  $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "========================================="

export DISPLAY=:99
export WINEPREFIX=/root/.wine
export WINEDEBUG=-all
export STAGING_WRITECOPY=1

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
EA_ROOT="$MT5_DIR/MQL5/Experts"
FILES_DIR="$MT5_DIR/MQL5/Files/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"

echo ""
echo "=== Step 1: Check Wine version ==="
wine --version

echo ""
echo "=== Step 2: Stop MT5 ==="
killall -9 terminal64.exe metaeditor64.exe 2>/dev/null
sleep 2
wineserver -k 2>/dev/null
sleep 3

echo ""
echo "=== Step 3: Ensure VNC is running ==="
if ! pgrep -x Xvfb > /dev/null; then
    echo "Starting Xvfb..."
    rm -f /tmp/.X99-lock /tmp/.X11-unix/X99 2>/dev/null
    Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX +render -noreset &
    sleep 3
fi
if ! pgrep -x x11vnc > /dev/null; then
    echo "Starting x11vnc..."
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw -xkb 2>/dev/null
    sleep 2
fi
echo "Xvfb PID: $(pgrep -x Xvfb)"
echo "x11vnc PID: $(pgrep -x x11vnc)"

echo ""
echo "=== Step 4: Update repo ==="
cd "$REPO_DIR"
git pull origin || true

echo ""
echo "=== Step 5: Deploy EA files ==="
mkdir -p "$EA_DIR"
mkdir -p "$FILES_DIR"
cp -v "$REPO_DIR/EA/"* "$EA_DIR/"
cp -v "$REPO_DIR/configs/"* "$FILES_DIR/"

echo ""
echo "=== Step 6: Check existing .ex5 ==="
find "$MT5_DIR" -name "PropFirmBot.ex5" 2>/dev/null
echo "(end of search)"

echo ""
echo "=== Step 7: Compile EA - Method 1 (MetaEditor CLI) ==="
cd "$MT5_DIR"
wine metaeditor64.exe /compile:"MQL5\Experts\PropFirmBot\PropFirmBot.mq5" /log 2>/dev/null &
METAED_PID=$!
sleep 25
kill $METAED_PID 2>/dev/null
wineserver -k 2>/dev/null
sleep 3
sync

echo ""
echo "=== Step 7b: Check compilation result ==="
find "$MT5_DIR" -name "PropFirmBot.ex5" 2>/dev/null
EX5_FOUND=$(find "$MT5_DIR" -name "PropFirmBot.ex5" 2>/dev/null | head -1)

if [ -z "$EX5_FOUND" ]; then
    echo "Method 1 failed. Trying Method 2..."

    echo ""
    echo "=== Step 8: Compile EA - Method 2 (Copy to root Experts + MT5 auto-compile) ==="
    # Copy .mqh includes next to .mq5 in root Experts dir
    cp "$EA_DIR/PropFirmBot.mq5" "$EA_ROOT/PropFirmBot.mq5"
    # Also copy all .mqh to Include dir so MT5 can find them
    mkdir -p "$MT5_DIR/MQL5/Include/PropFirmBot"
    cp "$EA_DIR/"*.mqh "$MT5_DIR/MQL5/Include/PropFirmBot/"
    # And copy .mqh next to .mq5 in the Experts folder
    cp "$EA_DIR/"*.mqh "$EA_ROOT/"

    echo "Starting MT5 to auto-compile..."
    cd "$MT5_DIR"
    wine terminal64.exe &
    sleep 20
    sync

    echo "Checking for .ex5 after MT5 auto-compile..."
    find "$MT5_DIR" -name "PropFirmBot.ex5" 2>/dev/null
    EX5_FOUND=$(find "$MT5_DIR" -name "PropFirmBot.ex5" 2>/dev/null | head -1)
fi

if [ -z "$EX5_FOUND" ]; then
    echo "Method 2 failed. Trying Method 3..."

    echo ""
    echo "=== Step 9: Compile EA - Method 3 (MetaEditor with full Windows path) ==="
    killall -9 terminal64.exe 2>/dev/null
    wineserver -k 2>/dev/null
    sleep 3

    cd "$MT5_DIR"
    wine metaeditor64.exe /compile:"C:\Program Files\MetaTrader 5\MQL5\Experts\PropFirmBot\PropFirmBot.mq5" /log 2>/dev/null &
    sleep 25
    wineserver -w 2>/dev/null
    sleep 3
    sync

    find "$MT5_DIR" -name "PropFirmBot.ex5" 2>/dev/null
    EX5_FOUND=$(find "$MT5_DIR" -name "PropFirmBot.ex5" 2>/dev/null | head -1)
fi

echo ""
echo "=== Step 10: Final status ==="
if [ -n "$EX5_FOUND" ]; then
    echo "SUCCESS! PropFirmBot.ex5 found at: $EX5_FOUND"
    ls -la "$EX5_FOUND"

    # Make sure it's also in the PropFirmBot subfolder
    cp "$EX5_FOUND" "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
else
    echo "WARNING: PropFirmBot.ex5 NOT found after all methods"
    echo "Checking compilation logs..."
    find "$MT5_DIR" -name "*.log" -newer "$EA_DIR/PropFirmBot.mq5" -exec echo "--- {} ---" \; -exec tail -5 {} \; 2>/dev/null
fi

echo ""
echo "=== Step 11: Start MT5 ==="
killall -9 terminal64.exe 2>/dev/null
wineserver -k 2>/dev/null
sleep 3

cd "$MT5_DIR"
wine terminal64.exe &
sleep 10

echo ""
echo "=== Step 12: Final check ==="
echo "MT5 process:"
ps aux | grep terminal64 | grep -v grep
echo ""
echo "VNC process:"
ps aux | grep x11vnc | grep -v grep
echo ""
echo "All .ex5 in Experts:"
find "$MT5_DIR/MQL5/Experts" -name "*.ex5" 2>/dev/null
echo ""
echo "========================================="
echo "  Script completed at $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "========================================="
