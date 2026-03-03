#!/bin/bash
# Compile PropFirmBot EA using MetaEditor
set -x
export DISPLAY=:99
export WINEPREFIX=/root/.wine

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
EDITOR="$MT5/MetaEditor64.exe"

echo "=== EA Compilation $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="

# Current state
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
BEFORE_TIME=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)

# Stop MT5 (it locks files)
pkill -f terminal64 2>/dev/null || true
sleep 3

# Try multiple MetaEditor compile syntaxes
echo ""
echo "--- Attempt 1: Relative path from MT5 dir ---"
cd "$MT5"
timeout 45 wine MetaEditor64.exe /compile:MQL5\\Experts\\PropFirmBot\\PropFirmBot.mq5 /include:MQL5 /log 2>&1
sleep 3
AFTER1=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
echo "After attempt 1: mtime=$AFTER1 (before=$BEFORE_TIME)"

if [ "$AFTER1" -le "$BEFORE_TIME" ]; then
    echo ""
    echo "--- Attempt 2: Full Windows path ---"
    cd "$MT5"
    timeout 45 wine MetaEditor64.exe "/compile:MQL5\Experts\PropFirmBot\PropFirmBot.mq5" /log 2>&1
    sleep 3
    AFTER2=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
    echo "After attempt 2: mtime=$AFTER2"
fi

if [ "${AFTER2:-$AFTER1}" -le "$BEFORE_TIME" ]; then
    echo ""
    echo "--- Attempt 3: cd to EA dir, compile by filename ---"
    cd "$EA_DIR"
    timeout 45 wine "$EDITOR" /compile:PropFirmBot.mq5 /log 2>&1
    sleep 3
    AFTER3=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
    echo "After attempt 3: mtime=$AFTER3"
fi

if [ "${AFTER3:-${AFTER2:-$AFTER1}}" -le "$BEFORE_TIME" ]; then
    echo ""
    echo "--- Attempt 4: Delete .ex5 and start MT5 to auto-compile ---"
    mv "$EA_DIR/PropFirmBot.ex5" "$EA_DIR/PropFirmBot.ex5.old" 2>/dev/null
    cd "$MT5"
    nohup wine terminal64.exe > /dev/null 2>&1 &
    disown
    echo "Waiting 25s for MT5 to auto-compile..."
    sleep 25

    if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
        AFTER4=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
        echo "New .ex5 exists! mtime=$AFTER4"
        ls -la "$EA_DIR/PropFirmBot.ex5"
    else
        echo ".ex5 NOT created, restoring old..."
        mv "$EA_DIR/PropFirmBot.ex5.old" "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
    fi
fi

# Check compilation log files
echo ""
echo "--- Looking for compilation logs ---"
find "$MT5/MQL5" -name "*.log" -newer "$EA_DIR/PropFirmBot.mq5" -mmin -5 2>/dev/null | while read f; do
    echo "=== $f ==="
    cat "$f" 2>/dev/null | tr -d '\0' | tail -20
done

# Final: make sure MT5 is running
echo ""
echo "--- Ensuring MT5 running ---"
if ! pgrep -f terminal64 > /dev/null 2>&1; then
    cd "$MT5"
    nohup wine terminal64.exe > /dev/null 2>&1 &
    disown
    sleep 8
fi
pgrep -f terminal64 > /dev/null && echo "MT5 OK" || echo "MT5 FAIL"

echo ""
echo "--- Final .ex5 ---"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
FINAL=$(stat -c%Y "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo 0)
if [ "$FINAL" -gt "$BEFORE_TIME" ]; then
    echo ">>> COMPILATION SUCCEEDED <<<"
else
    echo ">>> COMPILATION FAILED - still using old .ex5 <<<"
fi

echo "=== DONE ==="
