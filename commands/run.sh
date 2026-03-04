#!/bin/bash
# =============================================================
# Deploy updated EA + restart MT5 - 2026-03-04 improvements
# =============================================================

echo "=== Deploy + Restart - $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Display + VNC
echo "--- Display setup ---"
if ! pgrep -x Xvfb > /dev/null; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
    echo "Xvfb started"
else
    echo "Xvfb running"
fi
export DISPLAY=:99

if ! pgrep -x x11vnc > /dev/null; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    echo "VNC started"
else
    echo "VNC running"
fi

# 2. Stop MT5
echo "--- Stopping MT5 ---"
pkill -f terminal64 2>/dev/null || echo "Not running"
sleep 3

# 3. Pull latest code
echo "--- Pulling latest code ---"
cd /root/MT5-PropFirm-Bot
git fetch origin 2>/dev/null
git checkout claude/setup-bot-workflow-OUSci 2>/dev/null || true
git pull origin claude/setup-bot-workflow-OUSci 2>&1 || git pull 2>&1

# 4. Copy EA files
echo "--- Deploying EA files ---"
EA_DEST="$MT5/MQL5/Experts/PropFirmBot"
for f in EA/*.mq5 EA/*.mqh; do
    [ -f "$f" ] && cp "$f" "$EA_DEST/" && echo "  Copied: $(basename "$f")"
done

# 5. Copy config files
echo "--- Deploying configs ---"
CFG_DEST="$MT5/MQL5/Files/PropFirmBot"
for f in configs/*.json; do
    [ -f "$f" ] && cp "$f" "$CFG_DEST/" && echo "  Copied: $(basename "$f")"
done

# 6. Delete saved state so new max_positions takes effect
echo "--- Clearing saved state ---"
rm -f "$MT5/MQL5/Files/PropFirmBot_AccountState.dat"
echo "  Deleted old AccountState (will re-init with new settings)"

# 7. Start MT5
echo "--- Starting MT5 ---"
cd "$MT5"
WINEPREFIX=/root/.wine DISPLAY=:99 wine terminal64.exe /portable &
sleep 15

# 8. Verify
echo ""
echo "=== VERIFICATION ==="
if pgrep -a terminal64 > /dev/null; then
    echo "MT5: RUNNING"
else
    echo "MT5: NOT RUNNING (ERROR!)"
fi

echo ""
echo "--- Updated EA files ---"
ls -la "$EA_DEST/"*.mq5 "$EA_DEST/"*.mqh 2>/dev/null | awk '{print $6, $7, $8, $9}'

echo ""
echo "--- Updated configs ---"
ls -la "$CFG_DEST/"*.json 2>/dev/null | awk '{print $6, $7, $8, $9}'

echo ""
free -h | grep Mem

echo ""
echo "=== Done ==="
