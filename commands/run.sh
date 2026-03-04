#!/bin/bash
# =============================================================
# Restart MT5 + Deploy updated EA - 2026-03-04 fix spread
# =============================================================

echo "=== Restart MT5 + Deploy - $(date) ==="

# 1. Make sure display is running
echo "--- Setting up display ---"
if ! pgrep -x Xvfb > /dev/null; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
    echo "Xvfb started"
else
    echo "Xvfb already running"
fi
export DISPLAY=:99

# 2. Make sure VNC is running
if ! pgrep -x x11vnc > /dev/null; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    echo "VNC started"
else
    echo "VNC already running"
fi

# 3. Kill old MT5
echo "--- Stopping MT5 ---"
pkill -f terminal64 2>/dev/null || echo "No MT5 to kill"
sleep 3

# 4. Pull latest code from repo
echo "--- Pulling latest code ---"
cd /root/MT5-PropFirm-Bot
git pull origin claude/setup-bot-workflow-OUSci 2>&1 || git pull 2>&1

# 5. Copy updated EA files
echo "--- Deploying EA files ---"
EA_DEST="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Experts/PropFirmBot"
for f in EA/*.mq5 EA/*.mqh; do
    if [ -f "$f" ]; then
        cp "$f" "$EA_DEST/"
        echo "Copied: $f"
    fi
done

# 6. Start MT5
echo "--- Starting MT5 ---"
cd "/root/.wine/drive_c/Program Files/MetaTrader 5"
WINEPREFIX=/root/.wine DISPLAY=:99 wine terminal64.exe /portable &
sleep 15

# 7. Verify
echo ""
echo "--- Verification ---"
if pgrep -a terminal64; then
    echo "MT5 is RUNNING!"
else
    echo "WARNING: MT5 did not start"
fi

echo ""
echo "--- Memory ---"
free -h | grep Mem

echo ""
echo "=== Done ==="
