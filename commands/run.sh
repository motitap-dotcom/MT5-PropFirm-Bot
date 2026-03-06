#!/bin/bash
# Fix AutoTrading using xdotool to simulate Ctrl+E keyboard shortcut
echo "=== FIX AutoTrading via xdotool $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Install xdotool if needed
echo "[1] Installing xdotool..."
apt-get install -y xdotool 2>&1 | tail -3

# 2. Make sure MT5 is running
echo "[2] MT5 status:"
if ! pgrep -f terminal64 > /dev/null; then
    echo "MT5 not running, starting..."
    pgrep Xvfb || (Xvfb :99 -screen 0 1280x1024x24 & sleep 2)
    nohup wine "$MT5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading > /dev/null 2>&1 &
    sleep 15
fi
pgrep -f terminal64 && echo "MT5 RUNNING" || echo "MT5 NOT RUNNING"
echo ""

# 3. Find MT5 window
echo "[3] Finding MT5 window..."
WIN_ID=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
if [ -z "$WIN_ID" ]; then
    WIN_ID=$(xdotool search --name "terminal64" 2>/dev/null | head -1)
fi
if [ -z "$WIN_ID" ]; then
    WIN_ID=$(xdotool search --class "terminal64.exe" 2>/dev/null | head -1)
fi
if [ -z "$WIN_ID" ]; then
    # Try to find any Wine window
    echo "Trying all windows..."
    xdotool search --name "" 2>/dev/null | head -10
    WIN_ID=$(xdotool search --name "" 2>/dev/null | head -1)
fi

echo "Window ID: $WIN_ID"
echo ""

# 4. Send Ctrl+E to toggle AutoTrading
if [ -n "$WIN_ID" ]; then
    echo "[4] Activating window and sending Ctrl+E..."
    xdotool windowactivate "$WIN_ID" 2>/dev/null
    sleep 1
    xdotool key --window "$WIN_ID" ctrl+e 2>/dev/null
    echo "Sent Ctrl+E"
    sleep 2

    # Send it again just in case (toggle on)
    # First check if it worked by waiting for next trade attempt
else
    echo "[4] No window found, trying blind key send..."
    xdotool key ctrl+e 2>/dev/null
    echo "Sent blind Ctrl+E"
fi
echo ""

# 5. Also try: read the chart file properly and fix it
echo "[5] Fixing chart file..."
CHR_FILE="$MT5/profiles/charts/default/chart01.chr"
if [ -f "$CHR_FILE" ]; then
    echo "Chart file exists. Content:"
    cat "$CHR_FILE" 2>/dev/null | head -50
    echo "..."
    # Fix expert autotrading
    sed -i 's/ExpertAutoTrading=0/ExpertAutoTrading=1/g' "$CHR_FILE"
    echo "Fixed ExpertAutoTrading in chart file"
else
    echo "Chart file not found at: $CHR_FILE"
    echo "Looking for chart files..."
    find "$MT5" -name "*.chr" -type f 2>/dev/null
fi
echo ""

# 6. Wait and check EA log
echo "[6] Waiting 15 seconds for next trade attempt..."
sleep 15

LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "Last 10 log lines:"
    tail -10 "$LATEST_LOG" 2>&1
fi

echo ""
echo "=== DONE $(date -u) ==="
