#!/bin/bash
# Fix compilation and restart EA
echo "=== COMPILE AND RESTART $(date '+%Y-%m-%d %H:%M:%S %Z') ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"

# 1. Check current .ex5 timestamp
echo "--- Before compile ---"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
ls -la "$EA_DIR/PropFirmBot.mq5" 2>/dev/null

# 2. Try compilation with full error output
echo ""
echo "--- Attempting MetaEditor compilation ---"
cd "$EA_DIR"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Method 1: metaeditor64
echo "Method 1: metaeditor64 /compile"
wine "$MT5_BASE/metaeditor64.exe" /compile:"$EA_DIR/PropFirmBot.mq5" /log 2>&1
sleep 5

# Check for compilation log
echo ""
echo "--- MetaEditor log ---"
find "$MT5_BASE" -name "*.log" -newer "$EA_DIR/PropFirmBot.mq5" -mmin -3 2>/dev/null -exec echo "Log: {}" \; -exec tail -20 {} \;
find "$EA_DIR" -name "*.log" -mmin -3 2>/dev/null -exec echo "Log: {}" \; -exec tail -20 {} \;

echo ""
echo "--- After compile attempt ---"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null

# 3. If compilation didn't work, try removing old .ex5 and restarting MT5
# MT5 auto-compiles when .ex5 is missing
EX5_DATE=$(stat -c %Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null)
MQ5_DATE=$(stat -c %Y "$EA_DIR/PropFirmBot.mq5" 2>/dev/null)

if [ "$EX5_DATE" -lt "$MQ5_DATE" ] 2>/dev/null; then
    echo ""
    echo "--- .ex5 is older than .mq5 - removing old .ex5 to force recompile ---"
    rm -f "$EA_DIR/PropFirmBot.ex5"
    echo "Removed old .ex5. MT5 will recompile on next EA load."

    # Restart MT5 to force recompile and reload
    echo ""
    echo "--- Restarting MT5 ---"
    MT5_PID=$(pgrep -f "terminal64.exe" | head -1)
    if [ -n "$MT5_PID" ]; then
        echo "Stopping MT5 (PID=$MT5_PID)..."
        kill "$MT5_PID" 2>/dev/null
        sleep 5
        # Check if stopped
        if pgrep -f "terminal64.exe" > /dev/null; then
            echo "Force killing MT5..."
            kill -9 "$MT5_PID" 2>/dev/null
            sleep 3
        fi
    fi

    # Start MT5
    echo "Starting MT5..."
    cd "$MT5_BASE"
    DISPLAY=:99 WINEPREFIX=/root/.wine nohup wine "$MT5_BASE/terminal64.exe" /portable > /dev/null 2>&1 &
    sleep 15

    # Check if MT5 started
    if pgrep -f "terminal64.exe" > /dev/null; then
        echo "MT5 started successfully"
        NEW_PID=$(pgrep -f "terminal64.exe" | head -1)
        echo "New PID: $NEW_PID"
    else
        echo "ERROR: MT5 failed to start!"
    fi

    # Check if new .ex5 was created
    sleep 10
    echo ""
    echo "--- After MT5 restart ---"
    ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo "No .ex5 yet - MT5 may still be loading"
fi

# 4. Check latest EA log for new entries with our fixes
echo ""
echo "--- Latest EA log (checking for fix markers) ---"
EA_LATEST=$(ls -t "$MT5_BASE/MQL5/Logs"/*.log 2>/dev/null | head -1)
if [ -n "$EA_LATEST" ]; then
    TMPLOG="/tmp/ea_latest.txt"
    iconv -f UTF-16LE -t UTF-8 "$EA_LATEST" 2>/dev/null > "$TMPLOG" || \
      sed 's/\x00//g' "$EA_LATEST" > "$TMPLOG"
    echo "Log: $EA_LATEST ($(wc -l < "$TMPLOG") lines)"
    tail -20 "$TMPLOG"
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
