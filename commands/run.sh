#!/bin/bash
# Fix AutoTrading at ALL levels: global, per-chart, per-EA
echo "=== DEEP FIX AutoTrading $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Stop MT5
echo "[1] Stopping MT5..."
pkill -f terminal64 2>/dev/null
sleep 5
pkill -9 -f terminal64 2>/dev/null
sleep 2

# 2. Show ALL chart files
echo "[2] Chart files:"
find "$MT5/profiles" -name "*.chr" -type f 2>/dev/null
echo ""

# 3. Show content of chart files (the EA settings are here)
echo "[3] Chart file contents:"
for f in $(find "$MT5/profiles" -name "*.chr" -type f 2>/dev/null); do
    echo "=== $f ==="
    cat "$f" 2>/dev/null
    echo "---"
done
echo ""

# 4. Fix ALL chart files - enable EA auto trading
echo "[4] Fixing chart files..."
for f in $(find "$MT5/profiles" -name "*.chr" -type f 2>/dev/null); do
    # Fix ExpertAutoTrading
    sed -i 's/ExpertAutoTrading=0/ExpertAutoTrading=1/g' "$f"
    # Fix ExpertsAutoTrading
    sed -i 's/ExpertsAutoTrading=0/ExpertsAutoTrading=1/g' "$f"
    # Fix AllowLiveTrading for the EA
    sed -i 's/AllowLiveTrading=0/AllowLiveTrading=1/g' "$f"
    # Fix AutoTrading
    sed -i 's/AutoTrading=0/AutoTrading=1/g' "$f"
    echo "Fixed: $f"
done
echo ""

# 5. Show terminal.ini fully
echo "[5] terminal.ini:"
cat "$MT5/terminal.ini" 2>/dev/null
echo ""

# 6. Show common.ini [Experts] section
echo "[6] common.ini [Experts]:"
sed -n '/\[Experts\]/,/\[/p' "$MT5/config/common.ini" 2>/dev/null
echo ""

# 7. Check if there's an origin.ini or startup config
echo "[7] Other config files:"
find "$MT5/config" -type f 2>/dev/null | while read f; do
    echo "--- $f ---"
    cat "$f" 2>/dev/null | head -20
done
echo ""

# 8. Restart MT5
echo "[8] Starting MT5..."
export DISPLAY=:99
export WINEPREFIX=/root/.wine
pgrep Xvfb || (Xvfb :99 -screen 0 1280x1024x24 & sleep 2)

nohup wine "$MT5/terminal64.exe" /portable /login:11797849 /server:FundedNext-Server /autotrading > /dev/null 2>&1 &
sleep 15

echo "[9] Check:"
pgrep -f terminal64 > /dev/null && echo "MT5 RUNNING" || echo "MT5 NOT RUNNING"

# Check latest log
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "EA log (last 15 lines):"
    tail -15 "$LATEST_LOG" 2>&1
fi

echo "=== DONE $(date -u) ==="
