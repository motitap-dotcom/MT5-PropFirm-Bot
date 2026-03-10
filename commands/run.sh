#!/bin/bash
# Check .ex5 and restart MT5 with new version
echo "=== VERIFY COMPILE & RESTART $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

export DISPLAY=:99
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"

# 1. Check .ex5 timestamp
echo "[1] Current .ex5 file:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null

# The MetaEditor we used was from FundedNext directory
# Need to compile with the MT5 MetaEditor instead
echo ""
echo "[2] Recompiling with correct MetaEditor..."
WINEPREFIX=/root/.wine wine "$MT5_DIR/MetaEditor64.exe" /compile:"$EA_DIR/PropFirmBot.mq5" /log 2>&1
sleep 8
echo "After compile:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null

# Check compile log
echo ""
echo "[3] Compile log:"
cat "$EA_DIR/PropFirmBot.log" 2>/dev/null | strings | grep -i "result\|error\|warning" | head -5

# 3. Restart MT5
echo ""
echo "[4] Restarting MT5..."
pkill -9 -f terminal64 2>/dev/null
sleep 3

pgrep -x Xvfb > /dev/null || { Xvfb :99 -screen 0 1280x1024x24 & sleep 2; }
pgrep -x x11vnc > /dev/null || { x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null; sleep 1; }

cd "$MT5_DIR"
nohup wine "$MT5_DIR/terminal64.exe" /portable > /tmp/mt5_start.log 2>&1 &
echo "MT5 started (PID: $!)"
sleep 15

# 4. Verify
echo ""
echo "[5] Verification:"
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5: RUNNING"
else
    echo "MT5: NOT RUNNING!"
fi

# 5. Check EA loaded - wait for status file update
sleep 10
STATUS_FILE="$MT5_DIR/MQL5/Files/PropFirmBot/status.json"
if [ -f "$STATUS_FILE" ]; then
    echo ""
    echo "[6] Bot Status:"
    cat "$STATUS_FILE"
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
