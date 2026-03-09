#!/bin/bash
# =============================================================
# Start MT5 and verify EA loads from chart profile
# =============================================================

echo "============================================"
echo "  Start MT5 & Verify EA"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Make sure display is running
echo "=== [1] Display ==="
pgrep -f Xvfb > /dev/null && echo "Xvfb: OK" || {
    echo "Starting Xvfb..."
    Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX +render -noreset &
    sleep 2
}

# Start x11vnc for VNC access
pgrep -f x11vnc > /dev/null && echo "x11vnc: OK" || {
    echo "Starting x11vnc..."
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    sleep 1
}
echo ""

# 2. Kill any leftover MT5
pkill -f terminal64.exe 2>/dev/null
sleep 3

# 3. Start MT5
echo "=== [2] Start MT5 ==="
cd "$MT5_DIR"
screen -dmS mt5 bash -c "export DISPLAY=:99 && export WINEPREFIX=/root/.wine && cd '$MT5_DIR' && wine ./terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1"
echo "MT5 launched, waiting 45s for full startup + EA load..."
sleep 45

if pgrep -f terminal64.exe > /dev/null; then
    echo "MT5: RUNNING"
else
    echo "MT5: FAILED"
fi
echo ""

# 4. Wait extra for EA to initialize
echo "=== [3] Waiting 30s more for EA to connect... ==="
sleep 30
echo ""

# 5. Full status check
echo "=== [4] Bot Status ==="
if [ -f /var/bots/mt5_status.json ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null
else
    echo "Status file not found"
fi
echo ""

# 6. EA logs
echo "=== [5] EA Logs ==="
EA_LOG_DIR="$MT5_DIR/MQL5/Logs"
LATEST_LOG=$(ls -t "$EA_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "File: $(basename "$LATEST_LOG")"
    tail -40 "$LATEST_LOG" | strings
else
    echo "No EA logs"
fi
echo ""

# 7. MT5 journal
echo "=== [6] MT5 Journal ==="
JOURNAL_DIR="$MT5_DIR/Logs"
LATEST_JLOG=$(ls -t "$JOURNAL_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_JLOG" ]; then
    echo "File: $(basename "$LATEST_JLOG")"
    tail -30 "$LATEST_JLOG" | strings
else
    echo "No journal logs"
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
