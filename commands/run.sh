#!/bin/bash
# Deep debug: check display, MT5 process state, logs everywhere
echo "=== DEEP DEBUG $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Check Xvfb display
echo "=== DISPLAY ==="
pgrep -fa Xvfb
pgrep -fa x11vnc
echo "DISPLAY=$DISPLAY"
export DISPLAY=:99

# 2. Check if wine can run anything
echo ""
echo "=== WINE TEST ==="
WINEPREFIX=/root/.wine wine64 cmd /c "echo Wine works" 2>&1 | head -5

# 3. Check MT5 process and its stdout/stderr
echo ""
echo "=== MT5 PROCESS DETAILS ==="
pgrep -fa terminal64
# Check if terminal is actually responsive
ls -la /proc/$(pgrep -f "terminal64.exe /portable" | head -1)/fd 2>/dev/null | head -5

# 4. Check ALL log locations
echo ""
echo "=== ALL LOG LOCATIONS ==="
echo "--- MT5/Logs/ ---"
ls -la "$MT5/Logs/" 2>/dev/null
echo "--- MT5/MQL5/Logs/ ---"
ls -la "$MT5/MQL5/Logs/" 2>/dev/null | tail -5
echo "--- Wine user Logs ---"
find /root/.wine -name "*.log" -newer "$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null | head -10

# 5. Try to find MT5 crash/error output
echo ""
echo "=== WINE OUTPUT ==="
# Check journalctl for wine errors
journalctl --since "10 min ago" 2>/dev/null | grep -i "wine\|mt5\|terminal\|error\|crash" | tail -10

# 6. Try restarting Xvfb and x11vnc if not running
echo ""
echo "=== FIXING DISPLAY ==="
if ! pgrep -f Xvfb > /dev/null; then
    echo "Xvfb NOT running! Starting..."
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi
if ! pgrep -f x11vnc > /dev/null; then
    echo "x11vnc NOT running! Starting..."
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    sleep 1
fi

# 7. Kill old MT5 and restart properly
echo ""
echo "=== RESTARTING MT5 WITH OUTPUT ==="
pkill -9 -f terminal64 2>/dev/null
sleep 3

export DISPLAY=:99
export WINEPREFIX=/root/.wine
cd "$MT5"
# Capture wine output this time
wine64 terminal64.exe /portable > /tmp/mt5_stdout.txt 2>&1 &
MT5_PID=$!
echo "Started MT5 PID: $MT5_PID"

# Wait and check output
sleep 30
echo ""
echo "=== MT5 WINE OUTPUT (first 30s) ==="
cat /tmp/mt5_stdout.txt 2>/dev/null | head -20

# Is it still running?
if kill -0 $MT5_PID 2>/dev/null; then
    echo "MT5 still running (PID: $MT5_PID)"
else
    echo "MT5 CRASHED! Exit code: $?"
fi

# Wait more
sleep 60
echo ""
echo "=== EA LOG AFTER 90s ==="
EALOGDIR="$MT5/MQL5/Logs"
LATEST=$(ls -t "$EALOGDIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    NEWSIZE=$(stat -c%s "$LATEST" 2>/dev/null)
    echo "Log: $LATEST ($NEWSIZE bytes)"
    # Compare with old size (102898)
    if [ "$NEWSIZE" -gt 102898 ]; then
        echo "NEW LOG ENTRIES DETECTED!"
    else
        echo "NO new entries (still $NEWSIZE bytes)"
    fi
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -20
fi

# Check main log again
echo ""
echo "=== MT5 MAIN LOG ==="
ls -la "$MT5/Logs/" 2>/dev/null
LATEST=$(ls -t "$MT5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    SIZE=$(stat -c%s "$LATEST")
    echo "File: $LATEST ($SIZE bytes)"
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -20
else
    echo "NO main log files found!"
fi

echo ""
echo "=== DONE $(date) ==="
