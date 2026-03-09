#!/bin/bash
# =============================================================
# Compile EA using Windows-style paths for Wine
# =============================================================

echo "============================================"
echo "  Compile EA (Wine-compatible paths)"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Try compile with Windows-style path
echo "=== [1] Compile with Windows path ==="
wine "$MT5_DIR/MetaEditor64.exe" /compile:"C:\Program Files\MetaTrader 5\MQL5\Experts\PropFirmBot\PropFirmBot.mq5" /log:"C:\Program Files\MetaTrader 5\MQL5\Experts\PropFirmBot\compile.log" /inc:"C:\Program Files\MetaTrader 5\MQL5" 2>&1
echo "Waiting 20s for compile..."
sleep 20
pkill -f MetaEditor 2>/dev/null
sleep 2

echo ""
echo "Check .ex5:"
ls -la "$EA_DIR"/PropFirmBot.ex5 2>/dev/null || echo ".ex5 NOT found"
echo ""

# 2. If still missing, try alternative compile method
if [ ! -f "$EA_DIR/PropFirmBot.ex5" ]; then
    echo "=== [2] Alternative compile ==="
    cd "$MT5_DIR"
    wine MetaEditor64.exe /compile:"MQL5\Experts\PropFirmBot\PropFirmBot.mq5" /log 2>&1
    echo "Waiting 20s..."
    sleep 20
    pkill -f MetaEditor 2>/dev/null
    sleep 2
    echo ""
    ls -la "$EA_DIR"/PropFirmBot.ex5 2>/dev/null || echo "Still no .ex5"
    echo ""
fi

# 3. If STILL missing, check for any .ex5 in system
if [ ! -f "$EA_DIR/PropFirmBot.ex5" ]; then
    echo "=== [3] Search for any .ex5 backup ==="
    find /root/.wine -name "PropFirmBot.ex5" 2>/dev/null
    find /root -name "PropFirmBot.ex5" 2>/dev/null
    find /tmp -name "PropFirmBot.ex5" 2>/dev/null
    echo ""

    # Check if there's a Recycle bin copy or backup
    echo "Wine trash/recent:"
    find /root/.wine -name "*.ex5" 2>/dev/null
    echo ""
fi

# 4. Check compile logs for errors
echo "=== [4] Compile error logs ==="
if [ -f "$EA_DIR/compile.log" ]; then
    echo "--- compile.log ---"
    strings "$EA_DIR/compile.log" 2>/dev/null | head -30
fi
echo ""
echo "MetaEditor log:"
ls -t "$MT5_DIR"/MQL5/Logs/*.log 2>/dev/null | head -1 | xargs strings 2>/dev/null | tail -30
echo ""

# 5. MT5 status
echo "=== [5] MT5 status ==="
pgrep -f terminal64.exe > /dev/null && echo "MT5: RUNNING" || echo "MT5: NOT RUNNING"
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
