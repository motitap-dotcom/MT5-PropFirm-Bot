#!/bin/bash
# =============================================================
# Force recompile EA and verify it loads
# =============================================================

echo "============================================"
echo "  Force Recompile & Verify EA"
echo "  $(date '+%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Check current .ex5
echo "=== [1] Current .ex5 ==="
ls -la "$EA_DIR"/PropFirmBot.ex5 2>/dev/null
echo ""

# 2. Kill MT5 first (MetaEditor can't compile while MT5 locks files)
echo "=== [2] Stop MT5 ==="
pkill -f terminal64.exe 2>/dev/null
sleep 3
echo "MT5 stopped"
echo ""

# 3. Force recompile
echo "=== [3] Compile EA ==="
# Delete old .ex5 to force fresh compile
rm -f "$EA_DIR/PropFirmBot.ex5"
echo "Deleted old .ex5"

# Run MetaEditor
wine "$MT5_DIR/MetaEditor64.exe" /compile:"$EA_DIR/PropFirmBot.mq5" /log:"$EA_DIR/compile.log" 2>&1
echo "MetaEditor launched, waiting 15 seconds..."
sleep 15

# Kill MetaEditor after compile
pkill -f MetaEditor 2>/dev/null
sleep 2

# Check result
echo ""
echo "Compile result:"
ls -la "$EA_DIR"/PropFirmBot.ex5 2>/dev/null || echo "FAILED - .ex5 NOT created"
echo ""
if [ -f "$EA_DIR/compile.log" ]; then
    echo "Compile log:"
    cat "$EA_DIR/compile.log" 2>/dev/null | strings
fi
echo ""

# Also check MQL5 log dir for compile errors
echo "MetaEditor logs:"
ME_LOG_DIR="$MT5_DIR/MQL5/Logs"
ls -t "$ME_LOG_DIR"/*.log 2>/dev/null | head -3
LATEST=$(ls -t "$ME_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    echo "--- $(basename $LATEST) ---"
    tail -20 "$LATEST" | strings
fi
echo ""

# 4. Start MT5 again
echo "=== [4] Restart MT5 ==="
screen -dmS mt5 bash -c "export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1"
echo "MT5 starting..."
sleep 20

if pgrep -f terminal64.exe > /dev/null; then
    echo "MT5 RUNNING"
else
    echo "MT5 NOT RUNNING - trying again..."
    screen -dmS mt5 bash -c "export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1"
    sleep 15
    pgrep -f terminal64.exe > /dev/null && echo "MT5 RUNNING (2nd try)" || echo "MT5 FAILED TO START"
fi
echo ""

# 5. Wait and check EA status
echo "=== [5] EA Status After Restart ==="
sleep 10
if [ -f /var/bots/mt5_status.json ]; then
    python3 -m json.tool /var/bots/mt5_status.json 2>/dev/null
else
    echo "Status file not found yet"
fi
echo ""

# 6. Latest EA log after restart
echo "=== [6] EA Log After Restart ==="
LATEST_LOG=$(ls -t "$ME_LOG_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    tail -20 "$LATEST_LOG" | strings
fi
echo ""

echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
