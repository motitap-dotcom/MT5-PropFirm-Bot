#!/bin/bash
# Fix expertmode in chart files + restart MT5 + enable AutoTrading
echo "=== FIX EXPERTMODE $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Step 1: Kill MT5
echo "[1] Stopping MT5..."
screen -X -S mt5 quit 2>/dev/null
pkill -9 -f "terminal64\|start.exe" 2>/dev/null
sleep 3

# Step 2: Fix ALL chart files - set expertmode=3 (EA enabled + Allow Live Trading)
echo "[2] Fixing expertmode in all chart files..."
find "$MT5" -name "*.chr" 2>/dev/null | while read f; do
    if grep -q "expertmode" "$f" 2>/dev/null; then
        # Replace expertmode=0 or expertmode=1 with expertmode=3
        sed -i 's/expertmode=0/expertmode=3/g' "$f"
        sed -i 's/expertmode=1/expertmode=3/g' "$f"
        echo "  Fixed: $f"
    fi
done

# Verify the active chart file
echo ""
echo "[3] Verify active chart (Default/chart01.chr):"
CHART="$MT5/MQL5/Profiles/Charts/Default/chart01.chr"
cat "$CHART" 2>/dev/null | tr -d '\0' | grep -i "expert\|symbol" | head -10

# Step 3: Start MT5
echo ""
echo "[4] Starting MT5..."
cd "$MT5"
screen -dmS mt5 bash -c 'export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1'
sleep 25

# Step 4: Enable AutoTrading
echo "[5] Enabling AutoTrading..."
wine "C:\\at_keybd.exe" 2>&1
sleep 5

# Step 5: Check results
echo ""
echo "[6] AutoTrading state:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3

echo "[7] Last 10 EA entries:"
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -10

echo "[8] Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -12

echo "=== DONE $(date -u) ==="
