#!/bin/bash
# Restart MT5 with recompilation of EA
# IMPORTANT: uses nohup to prevent SSH session from hanging
echo "=== RESTART MT5 $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"

export DISPLAY=:99
export WINEPREFIX=/root/.wine

echo "--- 1. Current state ---"
ps aux | grep terminal64 | grep -v grep || echo "MT5 not running"
echo ""

echo "--- 2. Stop MT5 ---"
pkill -f terminal64 2>/dev/null || true
sleep 3
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "Force killing..."
    pkill -9 -f terminal64
    sleep 2
fi
echo "MT5 stopped"
# Kill any leftover Wine processes from compilation
pkill -f metaeditor 2>/dev/null || true
pkill -f wineserver 2>/dev/null || true
sleep 2
echo ""

echo "--- 3. Compile EA ---"
echo "Source files (newest first):"
ls -lt "$EA_DIR/"*.mq5 "$EA_DIR/"*.mqh 2>/dev/null | head -5
echo "Current .ex5:"
ls -la "$EA_DIR/"*.ex5 2>/dev/null
echo ""

# Try MetaEditor compilation with timeout
timeout 20 wine "$MT5/metaeditor64.exe" /compile:"$EA_DIR/PropFirmBot.mq5" /log 2>/dev/null || true
sleep 2

echo "After compile attempt:"
ls -la "$EA_DIR/"*.ex5 2>/dev/null
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

echo "--- 5. Start MT5 (nohup) ---"
cd "$MT5"
nohup wine "$MT5/terminal64.exe" > /dev/null 2>&1 &
disown
echo "MT5 launch command sent"
sleep 20

echo ""
echo "--- 6. Verify ---"
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5: RUNNING"
    ps aux | grep terminal64 | grep -v grep | awk '{printf "PID: %s | CPU: %s%% | MEM: %s%%\n", $2, $3, $4}'
else
    echo "MT5: NOT RUNNING - attempting second start..."
    nohup wine "$MT5/terminal64.exe" > /dev/null 2>&1 &
    disown
    sleep 15
    if pgrep -f terminal64 > /dev/null 2>&1; then
        echo "MT5: RUNNING (second attempt)"
        ps aux | grep terminal64 | grep -v grep | awk '{printf "PID: %s | CPU: %s%% | MEM: %s%%\n", $2, $3, $4}'
    else
        echo "MT5: FAILED TO START"
    fi
fi

echo ""
echo "Outbound connections:"
ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | head -5

echo ""
echo "EA .ex5:"
ls -la "$EA_DIR/"*.ex5 2>/dev/null

echo ""
echo "Terminal log (last 15 lines):"
TLOG=$(ls -t "$MT5/logs/"*.log 2>/dev/null | head -1)
[ -n "$TLOG" ] && cat "$TLOG" | tr -d '\0' | tail -15

echo ""
echo "EA log (last 10 lines):"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
[ -n "$EALOG" ] && cat "$EALOG" | tr -d '\0' | tail -10

echo ""
echo "=== RESTART DONE ==="
