#!/bin/bash
# Find MetaEditor and compile EA
echo "=== FIND & COMPILE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Find MetaEditor anywhere
echo "[1] Searching for MetaEditor..."
find /root/.wine -name "metaeditor*" -type f 2>/dev/null
find /root/.wine -name "MetaEditor*" -type f 2>/dev/null

# 2. List MT5 root dir to see what executables exist
echo ""
echo "[2] MT5 directory executables:"
ls -la "$MT5_DIR"/*.exe 2>/dev/null

# 3. Check if there's a metaeditor in path
echo ""
echo "[3] Wine C: drive search:"
find "/root/.wine/drive_c" -iname "*metaeditor*" 2>/dev/null

# 4. Check the current .ex5 timestamp vs .mq5 timestamp
echo ""
echo "[4] File timestamps:"
echo "Source (.mq5):"
ls -la "$MT5_DIR/MQL5/Experts/PropFirmBot/PropFirmBot.mq5" 2>/dev/null
echo "Compiled (.ex5):"
ls -la "$MT5_DIR/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null

# 5. Try to compile using MT5 terminal method (auto-compile on restart)
echo ""
echo "[5] Trying terminal compile method..."
# MT5 can compile if we place a script that triggers recompile
# Or we can try running metaeditor from terminal64 location
METAEDITOR=$(find /root/.wine -iname "metaeditor64.exe" -type f 2>/dev/null | head -1)
if [ -n "$METAEDITOR" ]; then
    echo "Found MetaEditor at: $METAEDITOR"
    export DISPLAY=:99
    WINEPREFIX=/root/.wine wine "$METAEDITOR" /compile:"$MT5_DIR/MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log 2>&1
    sleep 10
    echo "After compile:"
    ls -la "$MT5_DIR/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null
    # Check compile log
    cat "$MT5_DIR/MQL5/Experts/PropFirmBot/PropFirmBot.log" 2>/dev/null
else
    echo "MetaEditor NOT FOUND anywhere!"
    echo ""
    echo "Alternative: Download MetaEditor..."
    # Check if we can get it from MT5 installer
    ls -la "$MT5_DIR/" | head -20
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
