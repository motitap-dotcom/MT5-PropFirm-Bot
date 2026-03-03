#!/bin/bash
# Compile PropFirmBot EA on VPS
set -x
export DISPLAY=:99
export WINEPREFIX=/root/.wine

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
EDITOR="$MT5/metaeditor64.exe"

echo "=== EA Compilation $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="

# Show current state
echo "--- Source files ---"
ls -la "$EA_DIR/"*.mq5 "$EA_DIR/"*.mqh 2>/dev/null | head -15
echo ""
echo "--- Current .ex5 ---"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
BEFORE_SIZE=$(stat -c%s "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
BEFORE_TIME=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
echo "Before: size=$BEFORE_SIZE mtime=$BEFORE_TIME"

# Kill MT5 first (it locks the .ex5 file)
echo ""
echo "--- Stopping MT5 ---"
pkill -f terminal64 2>/dev/null || true
sleep 3
pgrep -f terminal64 && echo "WARNING: MT5 still running" || echo "MT5 stopped"

# Backup old .ex5
cp "$EA_DIR/PropFirmBot.ex5" "$EA_DIR/PropFirmBot.ex5.bak2" 2>/dev/null

# Try Method 1: MetaEditor with full path
echo ""
echo "--- Method 1: MetaEditor compile ---"
if [ -f "$EDITOR" ]; then
    echo "MetaEditor found at: $EDITOR"
    cd "$EA_DIR"

    # Run with timeout
    timeout 60 wine "$EDITOR" /compile:"$EA_DIR/PropFirmBot.mq5" /log 2>&1 || echo "MetaEditor returned non-zero"
    sleep 3

    # Check if .ex5 was updated
    AFTER_SIZE=$(stat -c%s "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
    AFTER_TIME=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
    echo "After: size=$AFTER_SIZE mtime=$AFTER_TIME"

    if [ "$AFTER_TIME" -gt "$BEFORE_TIME" ]; then
        echo "SUCCESS: .ex5 was recompiled!"
    else
        echo "Method 1 failed - .ex5 not updated"
    fi

    # Check for compilation log
    if [ -f "$EA_DIR/PropFirmBot.log" ]; then
        echo "--- Compilation log ---"
        cat "$EA_DIR/PropFirmBot.log" 2>/dev/null | tr -d '\0' | tail -30
    fi
else
    echo "MetaEditor not found!"
fi

# Try Method 2: Compile via MT5 terminal
echo ""
echo "--- Method 2: MT5 terminal compile ---"
AFTER_TIME2=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
if [ "$AFTER_TIME2" -le "$BEFORE_TIME" ]; then
    echo "Trying via MT5 terminal..."
    cd "$MT5"
    # Start MT5 which auto-compiles changed MQ5 files
    timeout 60 wine terminal64.exe /portable 2>/dev/null &
    MT5_PID=$!
    sleep 30
    kill $MT5_PID 2>/dev/null || true
    sleep 3

    AFTER_SIZE2=$(stat -c%s "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
    AFTER_TIME2=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
    echo "After Method 2: size=$AFTER_SIZE2 mtime=$AFTER_TIME2"

    if [ "$AFTER_TIME2" -gt "$BEFORE_TIME" ]; then
        echo "SUCCESS: .ex5 recompiled via MT5!"
    else
        echo "Method 2 also failed"
    fi
fi

# Start MT5 normally
echo ""
echo "--- Starting MT5 ---"
pkill -f terminal64 2>/dev/null || true
sleep 2
cd "$MT5"
nohup wine terminal64.exe > /dev/null 2>&1 &
disown
sleep 8

if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5 started OK (PID: $(pgrep -f terminal64 | head -1))"
else
    echo "ERROR: MT5 failed to start!"
fi

echo ""
echo "--- Final .ex5 state ---"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null

echo ""
echo "=== DONE ==="
