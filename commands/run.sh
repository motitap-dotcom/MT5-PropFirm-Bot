#!/bin/bash
# Reset MT5 chart profiles to force reload of NEW EA parameters
echo "=== RESET CHART PARAMS $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Stop MT5 gracefully
echo "=== STOPPING MT5 ==="
pkill -f terminal64 2>/dev/null
sleep 5
pkill -9 -f terminal64 2>/dev/null
sleep 2

# Verify MT5 is stopped
if pgrep -f terminal64 > /dev/null; then
    echo "WARNING: MT5 still running!"
    pkill -9 -f terminal64
    sleep 3
else
    echo "MT5 stopped successfully"
fi

# 2. Delete chart files in the active profile (Default)
echo ""
echo "=== DELETING OLD CHART PROFILES ==="
CHART_DIR="$MT5/MQL5/Profiles/Charts/Default"
if [ -d "$CHART_DIR" ]; then
    echo "Removing charts from: $CHART_DIR"
    ls -la "$CHART_DIR/"
    rm -f "$CHART_DIR/"chart*.chr
    rm -f "$CHART_DIR/"order.wnd
    echo "After cleanup:"
    ls -la "$CHART_DIR/" 2>/dev/null || echo "(empty)"
fi

# Also clear the non-MQL5 profile directory
CHART_DIR2="$MT5/Profiles/Charts/Default"
if [ -d "$CHART_DIR2" ]; then
    echo "Also removing from: $CHART_DIR2"
    rm -f "$CHART_DIR2/"chart*.chr
    rm -f "$CHART_DIR2/"order.wnd
fi

# 3. Verify startup.ini is correct (EA will load with source code defaults)
echo ""
echo "=== VERIFYING STARTUP CONFIG ==="
STARTUP="$MT5/config/startup.ini"
cat "$STARTUP"

# 4. Also update common.ini to ensure correct settings
COMMON="$MT5/config/common.ini"
echo ""
echo "=== CURRENT COMMON.INI ==="
cat "$COMMON"

# 5. Start MT5
echo ""
echo "=== STARTING MT5 ==="
cd "$MT5"
nohup wine64 terminal64.exe /portable > /dev/null 2>&1 &
echo "MT5 starting (PID: $!)"

# Wait for MT5 to fully initialize
echo "Waiting 30 seconds for MT5 to load..."
sleep 30

# 6. Check EA logs for new parameter values
echo ""
echo "=== EA LOG (checking new params) ==="
EALOGDIR="$MT5/MQL5/Logs"
LATEST=$(ls -t "$EALOGDIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | grep -E "INIT|Symbol|RiskMgr|NewsFilter|Signal|Scanning|XAUUSD|Symbols" | tail -30
else
    echo "No EA logs found yet"
fi

# Also check MT5 main logs
echo ""
echo "=== MT5 MAIN LOG ==="
LOGDIR="$MT5/Logs"
LATEST=$(ls -t "$LOGDIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -20
fi

echo ""
echo "=== DONE $(date) ==="
