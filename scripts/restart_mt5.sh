#!/bin/bash
# Restart MT5 with recompilation of EA
echo "=== RESTART MT5 $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"

echo "--- 1. Current state ---"
ps aux | grep terminal64 | grep -v grep || echo "MT5 not running"
echo ""

echo "--- 2. Compile EA ---"
cd "$EA_DIR"
echo "Source files:"
ls -la *.mq5 *.mqh 2>/dev/null | head -5
echo "Current .ex5:"
ls -la *.ex5 2>/dev/null
echo ""

# Try MetaEditor compilation
export DISPLAY=:99
export WINEPREFIX=/root/.wine
wine "$MT5/metaeditor64.exe" /compile:"$EA_DIR/PropFirmBot.mq5" /log 2>/dev/null &
COMPILER_PID=$!
sleep 10
kill $COMPILER_PID 2>/dev/null
wait $COMPILER_PID 2>/dev/null

echo "After MetaEditor compile:"
ls -la "$EA_DIR/"*.ex5 2>/dev/null
echo ""

echo "--- 3. Stop MT5 ---"
pkill -f terminal64 2>/dev/null || true
sleep 3
pgrep -f terminal64 > /dev/null 2>&1 && { echo "Force killing..."; pkill -9 -f terminal64; sleep 2; } || echo "MT5 stopped"
echo ""

echo "--- 4. Ensure display is running ---"
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
    echo "Xvfb started"
else
    echo "Xvfb already running"
fi

if ! pgrep -x x11vnc > /dev/null 2>&1; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    echo "x11vnc started"
else
    echo "x11vnc already running"
fi
echo ""

echo "--- 5. Start MT5 ---"
cd "$MT5"
DISPLAY=:99 WINEPREFIX=/root/.wine wine "$MT5/terminal64.exe" &
MT5_PID=$!
echo "MT5 started PID=$MT5_PID"
sleep 15

echo ""
echo "--- 6. Verify ---"
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5: RUNNING"
    ps aux | grep terminal64 | grep -v grep | awk '{printf "PID: %s | CPU: %s%% | MEM: %s%%\n", $2, $3, $4}'
else
    echo "MT5: NOT RUNNING - PROBLEM!"
fi

echo ""
echo "Outbound connections:"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -5

echo ""
echo "EA .ex5 status:"
ls -la "$EA_DIR/"*.ex5 2>/dev/null

echo ""
echo "Terminal log (last 10 lines):"
TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
[ -n "$TLOG" ] && cat "$TLOG" | tr -d '\0' | tail -10

echo ""
echo "=== RESTART DONE ==="
