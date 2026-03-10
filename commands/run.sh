#!/bin/bash
# Force recompile by deleting old .ex5 + restart
echo "=== FORCE RECOMPILE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

export DISPLAY=:99
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"

# 1. Stop MT5
echo "[1] Stopping MT5..."
pkill -9 -f terminal64 2>/dev/null
sleep 3

# 2. Delete old .ex5 to force recompile
echo "[2] Removing old .ex5..."
rm -f "$EA_DIR/PropFirmBot.ex5"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo ".ex5 deleted successfully"

# 3. Compile with MetaEditor (full path, correct MT5 dir)
echo ""
echo "[3] Compiling with MetaEditor..."
cd "$MT5_DIR"
WINEPREFIX=/root/.wine wine "$MT5_DIR/MetaEditor64.exe" /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log 2>&1
sleep 12
echo ""
echo "After compile:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo "NO .ex5 CREATED!"

# 4. If still no .ex5, try FundedNext MetaEditor with full Wine path
if [ ! -f "$EA_DIR/PropFirmBot.ex5" ]; then
    echo ""
    echo "[3b] Trying FundedNext MetaEditor..."
    WINEPREFIX=/root/.wine wine "/root/.wine/drive_c/Program Files/FundedNext MT5 Terminal/MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5\MQL5\Experts\PropFirmBot\PropFirmBot.mq5" /log 2>&1
    sleep 12
    echo "After compile:"
    ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo "STILL NO .ex5!"
fi

# 5. Start MT5 (it will auto-compile if .mq5 is newer than .ex5 or .ex5 missing)
echo ""
echo "[4] Starting MT5..."
pgrep -x Xvfb > /dev/null || { Xvfb :99 -screen 0 1280x1024x24 & sleep 2; }
pgrep -x x11vnc > /dev/null || { x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null; }

cd "$MT5_DIR"
nohup wine "$MT5_DIR/terminal64.exe" /portable > /tmp/mt5_start.log 2>&1 &
echo "MT5 started"
sleep 20

# 6. Check result
echo ""
echo "[5] Final check:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo "NO .ex5!"
pgrep -f terminal64 > /dev/null && echo "MT5: RUNNING" || echo "MT5: NOT RUNNING!"

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
