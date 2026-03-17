#!/bin/bash
# Compile EA with correct MetaEditor path + restart MT5
echo "=== COMPILE + RESTART $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# STEP 1: Stop MT5
echo "--- 1. Stop MT5 ---"
pkill -f terminal64 2>/dev/null
sleep 3
pkill -9 -f terminal64 2>/dev/null
wineserver -k 2>/dev/null
sleep 2
echo "MT5 stopped"

# STEP 2: Compile with correct filename
echo ""
echo "--- 2. Compile EA ---"
cd "$MT5"
wine MetaEditor64.exe /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log:"MQL5/Experts/PropFirmBot/compile.log" 2>/dev/null
sleep 15

# Check compile result
echo "Compile log:"
cat "$MT5/MQL5/Experts/PropFirmBot/compile.log" 2>/dev/null | tr -d '\0' || echo "(no log at EA dir)"
cat "$MT5/compile.log" 2>/dev/null | tr -d '\0' || echo "(no log at MT5 dir)"

# Check .ex5
EX5="$MT5/MQL5/Experts/PropFirmBot/PropFirmBot.ex5"
echo ""
echo "EX5 file:"
ls -la "$EX5" 2>/dev/null || echo "NOT FOUND"

# Also check if there are compilation errors in MQL5 log dir
echo ""
echo "MetaEditor logs:"
ls -lt "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -3
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    cat "$LATEST_LOG" | tr -d '\0' | grep -i "compil\|error\|warning" | tail -10
fi

# STEP 3: Restart MT5
echo ""
echo "--- 3. Start MT5 ---"
cd "$MT5"
nohup wine terminal64.exe /portable > /tmp/mt5_wine.log 2>&1 &
disown
sleep 20

# STEP 4: Verify new code
echo ""
echo "--- 4. Verify ---"
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5: RUNNING"
else
    echo "MT5: NOT RUNNING"
fi

LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo ""
    echo "--- RiskMgr init line (looking for DD_Mode) ---"
    cat "$LATEST_LOG" | tr -d '\0' | grep "RiskMgr" | tail -5
    echo ""
    echo "--- Guardian init ---"
    cat "$LATEST_LOG" | tr -d '\0' | grep "GUARDIAN" | tail -5
    echo ""
    echo "--- Last 10 lines ---"
    cat "$LATEST_LOG" | tr -d '\0' | tail -10
fi

echo ""
echo "=== DONE $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
