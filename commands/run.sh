#!/bin/bash
# Fix AutoTrading and restart MT5
export DISPLAY=:99
export WINEPREFIX=/root/.wine

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "=== TIME: $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

# Step 1: Kill MT5
echo "=== Step 1: Kill MT5 ==="
pkill -f terminal64.exe 2>/dev/null || true
sleep 5

# Step 2: Enable AutoTrading in ALL config files
echo ""
echo "=== Step 2: Fix AutoTrading in config files ==="

# Main common.ini
COMMON_INI="$MT5_BASE/config/common.ini"
echo "Current common.ini:"
cat "$COMMON_INI" 2>/dev/null

# Make sure AutoTrading is enabled
if grep -q "AutoTrading" "$COMMON_INI" 2>/dev/null; then
    sed -i 's/AutoTrading=.*/AutoTrading=1/' "$COMMON_INI"
else
    echo "AutoTrading=1" >> "$COMMON_INI"
fi

# Also check ExpertsEnable
if grep -q "ExpertsEnable" "$COMMON_INI" 2>/dev/null; then
    sed -i 's/ExpertsEnable=.*/ExpertsEnable=1/' "$COMMON_INI"
else
    echo "ExpertsEnable=1" >> "$COMMON_INI"
fi

# Check all .ini files for AutoTrading settings
echo ""
echo "Fixing all ini files..."
find "$MT5_BASE" -name "*.ini" -exec grep -l "AutoTrading\|ExpertsEnable\|ExpertsTrades" {} \; 2>/dev/null | while read f; do
    echo "  Fixing: $f"
    sed -i 's/AutoTrading=0/AutoTrading=1/g' "$f"
    sed -i 's/ExpertsEnable=0/ExpertsEnable=1/g' "$f"
    sed -i 's/ExpertsTrades=0/ExpertsTrades=1/g' "$f"
done

echo ""
echo "Updated common.ini:"
cat "$COMMON_INI" 2>/dev/null

# Also check chart profiles for EA auto-trading setting
echo ""
echo "=== Checking chart .chr files for ExpertAutoTrading ==="
find "$MT5_BASE/Profiles" -name "*.chr" 2>/dev/null | while read f; do
    if grep -q "ExpertAutoTrading" "$f" 2>/dev/null; then
        echo "  Found in: $f"
        grep "ExpertAutoTrading" "$f"
        sed -i 's/ExpertAutoTrading=0/ExpertAutoTrading=1/g' "$f"
    fi
done

# Step 3: Start MT5
echo ""
echo "=== Step 3: Start MT5 with autotrading ==="
cd "$MT5_BASE"
nohup wine terminal64.exe /autotrading > /dev/null 2>&1 &
sleep 20

echo ""
echo "=== MT5 Process ==="
ps aux | grep terminal64 | grep -v grep

# Step 4: Check EA log for signal + trade
echo ""
echo "=== Step 4: EA Log (new session) ==="
LOG_FILE="$MT5_BASE/MQL5/Logs/$(date -u +%Y%m%d).log"
tail -30 "$LOG_FILE" 2>/dev/null || echo "No log yet"

echo ""
echo "DONE $(date)"
