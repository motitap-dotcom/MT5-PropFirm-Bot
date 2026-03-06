#!/bin/bash
# Verify: is AutoTrading ON and are trades executing?
echo "=== VERIFY TRADES $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99

# 1. Check if AutoTrading was toggled off again by the extra Ctrl+E
echo "[1] EA log - checking for enabled/disabled messages:"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
grep -i "automated trading" "$EALOG" 2>/dev/null
echo ""

# 2. If it was toggled off again (odd number of Ctrl+E), toggle it back on
LAST_STATE=$(grep -i "automated trading" "$EALOG" 2>/dev/null | tail -1)
echo "Last state: $LAST_STATE"
if echo "$LAST_STATE" | grep -q "disabled"; then
    echo "AutoTrading is OFF! Sending single Ctrl+E to first window only..."
    WIN_ID=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
    if [ -n "$WIN_ID" ]; then
        xdotool windowfocus --sync "$WIN_ID" 2>/dev/null
        sleep 1
        xdotool key --window "$WIN_ID" --clearmodifiers ctrl+e 2>/dev/null
        echo "Sent Ctrl+E to $WIN_ID"
        sleep 3
        # Verify
        grep -i "automated trading" "$EALOG" 2>/dev/null | tail -3
    fi
fi
echo ""

# 3. Wait for next 15-minute bar and check for trades
echo "[2] Waiting for activity (30 seconds)..."
sleep 30

echo "[3] Latest EA log:"
tail -20 "$EALOG" 2>&1
echo ""

# 4. Account status
echo "[4] mt5_status.json:"
cat /var/bots/mt5_status.json 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "N/A"

echo ""
echo "=== DONE $(date -u) ==="
