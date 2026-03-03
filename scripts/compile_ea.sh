#!/bin/bash
# Find and run MetaEditor to compile PropFirmBot EA
set -x
export DISPLAY=:99
export WINEPREFIX=/root/.wine

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"

echo "=== EA Compilation $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="

# Step 1: Find MetaEditor
echo "--- Searching for MetaEditor ---"
find /root/.wine -name "metaeditor*.exe" -type f 2>/dev/null
find /root/.wine -name "MetaEditor*.exe" -type f 2>/dev/null

# Also check what's in the MT5 directory
echo ""
echo "--- Files in MT5 root ---"
ls -la "$MT5/"*.exe 2>/dev/null

echo ""
echo "--- Current .ex5 state ---"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
BEFORE_TIME=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)

# Step 2: Stop MT5
echo ""
echo "--- Stopping MT5 ---"
pkill -f terminal64 2>/dev/null || true
sleep 3

# Step 3: Try to find and run MetaEditor
EDITOR=""
for path in \
    "$MT5/metaeditor64.exe" \
    "$MT5/MetaEditor64.exe" \
    "$MT5/metaeditor.exe" \
    "$MT5/MetaEditor.exe" \
    "/root/.wine/drive_c/Program Files/MetaTrader 5/metaeditor64.exe" \
    $(find /root/.wine -name "metaeditor64.exe" -type f 2>/dev/null | head -1) \
    $(find /root/.wine -name "MetaEditor64.exe" -type f 2>/dev/null | head -1); do
    if [ -f "$path" ] 2>/dev/null; then
        EDITOR="$path"
        echo "Found MetaEditor at: $EDITOR"
        break
    fi
done

if [ -n "$EDITOR" ]; then
    echo "--- Compiling with MetaEditor ---"
    cd "$EA_DIR"
    timeout 45 wine "$EDITOR" /compile:"$EA_DIR/PropFirmBot.mq5" /log 2>&1
    sleep 3

    # Check for log
    for logfile in "$EA_DIR/PropFirmBot.log" "$EA_DIR/"*.log; do
        if [ -f "$logfile" ]; then
            echo "Log: $logfile"
            cat "$logfile" 2>/dev/null | tr -d '\0' | tail -20
        fi
    done
else
    echo "MetaEditor NOT FOUND anywhere!"
    echo ""
    echo "--- Attempting manual compile via MT5 terminal ---"
    # Delete old .ex5 to force MT5 to recompile when it loads the EA
    echo "Removing old .ex5 to force recompile on load..."
    mv "$EA_DIR/PropFirmBot.ex5" "$EA_DIR/PropFirmBot.ex5.old" 2>/dev/null || true

    # Start MT5 - it should try to compile the EA when loading
    cd "$MT5"
    nohup wine terminal64.exe > /dev/null 2>&1 &
    disown
    echo "Waiting 30s for MT5 to start and compile..."
    sleep 30

    # Check if new .ex5 was created
    if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
        AFTER_TIME=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
        echo "NEW .ex5 created! Time: $AFTER_TIME"
        ls -la "$EA_DIR/PropFirmBot.ex5"
        echo "SUCCESS - MT5 auto-compiled the EA!"
    else
        echo ".ex5 was NOT recreated. MT5 didn't auto-compile."
        echo "Restoring old .ex5..."
        mv "$EA_DIR/PropFirmBot.ex5.old" "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || true

        echo ""
        echo "WORKAROUND: Trying to download MetaEditor..."
        # MetaEditor is sometimes not included. Try to extract from MT5 installer
        # or download it
        cd "$MT5"
        if [ -f "metaeditor64.exe" ]; then
            echo "metaeditor64.exe exists now!"
        else
            echo "Need to install MetaEditor manually"
            # Check if there's a setup file
            find /root/.wine -name "*.exe" | grep -i editor
        fi
    fi
fi

# Ensure MT5 is running
echo ""
echo "--- Ensuring MT5 is running ---"
if ! pgrep -f terminal64 > /dev/null 2>&1; then
    cd "$MT5"
    nohup wine terminal64.exe > /dev/null 2>&1 &
    disown
    sleep 8
fi

if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5 running OK (PID: $(pgrep -f terminal64 | head -1))"
else
    echo "ERROR: MT5 not running!"
fi

echo ""
echo "--- Final .ex5 state ---"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo "No .ex5 found!"

echo ""
echo "=== DONE ==="
