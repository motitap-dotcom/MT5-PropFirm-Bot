#!/bin/bash
# Send exactly ONE Ctrl+E to the FIRST FundedNext window ONLY
echo "=== ENABLE AutoTrading $(date -u) ==="

export DISPLAY=:99

# Find first window only
WIN_ID=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
echo "Window: $WIN_ID ($(xdotool getwindowname "$WIN_ID" 2>/dev/null))"

# Send single Ctrl+E
xdotool windowfocus --sync "$WIN_ID" 2>/dev/null
sleep 1
xdotool key --window "$WIN_ID" --clearmodifiers ctrl+e 2>/dev/null
echo "Sent Ctrl+E"
sleep 5

# Check
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
echo ""
echo "Last 5 log lines:"
tail -5 "$EALOG" 2>&1

# Wait for next 15min bar and check trades
echo ""
echo "Waiting 60 seconds for next bar..."
sleep 60

echo "After wait:"
tail -20 "$EALOG" 2>&1

echo ""
echo "=== DONE $(date -u) ==="
