#!/bin/bash
# =============================================================
# Compile EA + Restart MT5 - 2026-03-04
# =============================================================

echo "=== Compile + Restart - $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
export DISPLAY=:99

# 1. Stop MT5
echo "--- Stopping MT5 ---"
pkill -f terminal64 2>/dev/null
sleep 5
pkill -9 -f terminal64 2>/dev/null
sleep 2

# 2. Backup old .ex5
echo "--- Backing up old .ex5 ---"
cp "$EA_DIR/PropFirmBot.ex5" "$EA_DIR/PropFirmBot.ex5.before_update" 2>/dev/null
ls -la "$EA_DIR/PropFirmBot.ex5"* 2>/dev/null

# 3. Compile with MetaEditor
echo "--- Compiling EA ---"
WINEPREFIX=/root/.wine wine "$MT5/metaeditor64.exe" /compile:"$EA_DIR/PropFirmBot.mq5" /log 2>/dev/null
sleep 10

# Check compile result
echo "--- Compile result ---"
NEW_EX5="$EA_DIR/PropFirmBot.ex5"
if [ -f "$NEW_EX5" ]; then
    OLD_SIZE=$(stat -c%s "$EA_DIR/PropFirmBot.ex5.before_update" 2>/dev/null || echo 0)
    NEW_SIZE=$(stat -c%s "$NEW_EX5")
    echo "Old .ex5 size: $OLD_SIZE bytes"
    echo "New .ex5 size: $NEW_SIZE bytes"
    if [ "$OLD_SIZE" != "$NEW_SIZE" ]; then
        echo "SIZE CHANGED - compilation produced new binary!"
    else
        echo "Same size - may or may not have changed"
    fi
    ls -la "$NEW_EX5"
else
    echo "ERROR: No .ex5 file found after compile!"
fi

# Check for compile errors
COMPILE_LOG="$EA_DIR/PropFirmBot.log"
if [ -f "$COMPILE_LOG" ]; then
    echo "--- Compile log ---"
    cat "$COMPILE_LOG" | tr -d '\0' | tail -20
fi

# 4. Start MT5
echo "--- Starting MT5 ---"
cd "$MT5"
WINEPREFIX=/root/.wine DISPLAY=:99 wine terminal64.exe /portable &
sleep 15

# 5. Verify
echo ""
echo "=== VERIFICATION ==="
if ps aux | grep -q "[t]erminal64"; then
    echo "MT5: RUNNING"
else
    echo "MT5: NOT RUNNING"
fi

# 6. Wait for EA to load and check status
sleep 5
echo ""
echo "--- Latest EA log lines ---"
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" | tr -d '\0' | tail -15
fi

echo ""
echo "=== Done ==="
