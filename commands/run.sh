#!/bin/bash
# =============================================================
# Compile EA - focused approach - 2026-03-04
# =============================================================

echo "=== Compile EA - $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Record old hash
OLD_HASH=$(md5sum "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d' ' -f1)
echo "Old hash: $OLD_HASH"

# Stop MT5
echo "--- Stopping MT5 ---"
pkill -f terminal64 2>/dev/null; sleep 3; pkill -9 -f terminal64 2>/dev/null; sleep 2

# Try compile from MT5 directory
echo "--- Compiling ---"
cd "$MT5"

# Method 1: relative path from MT5 dir
echo "Method 1:"
wine metaeditor64.exe /compile:"MQL5\Experts\PropFirmBot\PropFirmBot.mq5" /log 2>&1 | tail -5
sleep 5
HASH1=$(md5sum "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d' ' -f1)
echo "Hash after: $HASH1"

if [ "$OLD_HASH" = "$HASH1" ]; then
    # Method 2: absolute path
    echo "Method 2:"
    wine "$MT5/metaeditor64.exe" /compile:"C:\Program Files\MetaTrader 5\MQL5\Experts\PropFirmBot\PropFirmBot.mq5" /log 2>&1 | tail -5
    sleep 5
    HASH2=$(md5sum "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d' ' -f1)
    echo "Hash after: $HASH2"

    if [ "$OLD_HASH" = "$HASH2" ]; then
        # Method 3: try from EA directory
        echo "Method 3:"
        cd "$EA_DIR"
        wine "$MT5/metaeditor64.exe" /compile:PropFirmBot.mq5 /log 2>&1 | tail -5
        sleep 5
        HASH3=$(md5sum "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d' ' -f1)
        echo "Hash after: $HASH3"

        if [ "$OLD_HASH" = "$HASH3" ]; then
            # Method 4: xdotool via MT5 GUI
            echo "Method 4: xdotool GUI"
            apt-get install -y -qq xdotool > /dev/null 2>&1
            cd "$MT5"
            wine terminal64.exe /portable &
            sleep 12
            # F4=MetaEditor, F7=Compile, Alt+F4=Close
            xdotool key F4; sleep 8
            xdotool key F7; sleep 8
            xdotool key alt+F4; sleep 3
            HASH4=$(md5sum "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d' ' -f1)
            echo "Hash after: $HASH4"
        fi
    fi
fi

FINAL_HASH=$(md5sum "$EA_DIR/PropFirmBot.ex5" 2>/dev/null | cut -d' ' -f1)
echo ""
echo "=== RESULT ==="
echo "Old: $OLD_HASH"
echo "New: $FINAL_HASH"
if [ "$OLD_HASH" != "$FINAL_HASH" ]; then
    echo "COMPILED SUCCESSFULLY!"
else
    echo "COMPILATION FAILED - need manual VNC compile"
fi

# Check compile log
if [ -f "$EA_DIR/PropFirmBot.log" ]; then
    echo ""
    echo "--- Compile log ---"
    cat "$EA_DIR/PropFirmBot.log" | tr -d '\0' | tail -10
fi

# Ensure MT5 is running
if ! ps aux | grep -q "[t]erminal64"; then
    echo "--- Starting MT5 ---"
    cd "$MT5"
    wine terminal64.exe /portable &
    sleep 12
fi

echo ""
ps aux | grep "[t]erminal64" | head -2
echo "=== Done ==="
