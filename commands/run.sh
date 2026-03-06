#!/bin/bash
# Fix expertmode directly - handle UTF-16 encoding
echo "=== FIX EXPERTMODE v2 $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# Kill MT5 first
screen -X -S mt5 quit 2>/dev/null
pkill -9 -f "terminal64\|start.exe" 2>/dev/null
sleep 3

# Fix the active chart file directly
CHART="$MT5/MQL5/Profiles/Charts/Default/chart01.chr"
echo "[1] Chart file encoding:"
file "$CHART" 2>/dev/null

echo "[2] Current expertmode:"
cat "$CHART" 2>/dev/null | tr -d '\0' | grep "expertmode"

echo "[3] Fixing..."
# Read, strip nulls, replace, write back
cat "$CHART" 2>/dev/null | tr -d '\0' | sed 's/expertmode=0/expertmode=3/g' > /tmp/chart01_fixed.chr
# Verify fix worked
grep "expertmode" /tmp/chart01_fixed.chr
# Copy back
cp /tmp/chart01_fixed.chr "$CHART"

# Also fix ALL other chart files the same way
for f in $(find "$MT5" -name "*.chr" 2>/dev/null); do
    if cat "$f" 2>/dev/null | tr -d '\0' | grep -q "expertmode=0"; then
        cat "$f" | tr -d '\0' | sed 's/expertmode=0/expertmode=3/g' > /tmp/chr_fix.tmp
        cp /tmp/chr_fix.tmp "$f"
        echo "  Fixed: $(basename "$(dirname "$f")")/$(basename "$f")"
    fi
done

echo "[4] Verify:"
cat "$CHART" 2>/dev/null | tr -d '\0' | grep "expertmode"

# Restart MT5
echo "[5] Starting MT5..."
cd "$MT5"
screen -dmS mt5 bash -c 'export DISPLAY=:99 && export WINEPREFIX=/root/.wine && wine terminal64.exe /portable /login:11797849 /server:FundedNext-Server 2>&1'
sleep 25

# Enable AutoTrading
echo "[6] Enabling AutoTrading..."
wine "C:\\at_keybd.exe" 2>&1
sleep 8

# Check
echo "[7] Result:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
cat "$EALOG" 2>/dev/null | tr -d '\0' | grep "automated trading" | tail -3
echo ""
cat "$EALOG" 2>/dev/null | tr -d '\0' | tail -10

echo "[8] Status:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null | head -12

echo "=== DONE $(date -u) ==="
