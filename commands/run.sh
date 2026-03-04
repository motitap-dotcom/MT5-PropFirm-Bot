#!/bin/bash
# =============================================================
# Recompile EA and restart MT5
# =============================================================

echo "=== Recompile & Restart - $(date) ==="
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"

# Show timestamps before compile
echo "--- File Timestamps (Before) ---"
echo "Source (.mq5): $(stat -c '%y' "$EA_DIR/PropFirmBot.mq5" 2>/dev/null)"
echo "Compiled (.ex5): $(stat -c '%y' "$EA_DIR/PropFirmBot.ex5" 2>/dev/null)"
echo ""

# Backup current .ex5
if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    cp "$EA_DIR/PropFirmBot.ex5" "$EA_DIR/PropFirmBot.ex5.bak_before_recompile"
    echo "Backed up current .ex5"
fi

# Kill MT5 if running
echo "--- Stopping MT5 ---"
pkill -f terminal64 2>/dev/null
sleep 3
pgrep -a terminal64 && echo "MT5 still running!" || echo "MT5 stopped"
echo ""

# Compile EA
echo "--- Compiling EA ---"
cd "$MT5_DIR"
wine metaeditor64.exe /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log:compile.log 2>/dev/null
sleep 10

# Show compile log
echo "--- Compile Log ---"
if [ -f "$MT5_DIR/compile.log" ]; then
    cat "$MT5_DIR/compile.log"
else
    echo "No compile.log found, checking MQL5 logs..."
    ls -la "$MT5_DIR/MQL5/Logs/" 2>/dev/null | tail -5
fi
echo ""

# Check if .ex5 was updated
echo "--- File Timestamps (After) ---"
echo "Source (.mq5): $(stat -c '%y' "$EA_DIR/PropFirmBot.mq5" 2>/dev/null)"
echo "Compiled (.ex5): $(stat -c '%y' "$EA_DIR/PropFirmBot.ex5" 2>/dev/null)"

NEW_SIZE=$(stat -c '%s' "$EA_DIR/PropFirmBot.ex5" 2>/dev/null)
OLD_SIZE=$(stat -c '%s' "$EA_DIR/PropFirmBot.ex5.bak_before_recompile" 2>/dev/null)
echo "Old .ex5 size: $OLD_SIZE bytes"
echo "New .ex5 size: $NEW_SIZE bytes"
echo ""

# Start MT5
echo "--- Starting MT5 ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# Make sure Xvfb is running
if ! pgrep -x Xvfb > /dev/null; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
    echo "Started Xvfb"
fi

# Start x11vnc if not running
if ! pgrep -x x11vnc > /dev/null; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    echo "Started x11vnc"
fi

# Start MT5
cd "$MT5_DIR"
wine terminal64.exe &
sleep 10

# Verify
echo ""
echo "--- Verification ---"
pgrep -a terminal64 && echo "MT5 is RUNNING" || echo "MT5 FAILED to start!"
echo ""

echo "=== Done ==="
