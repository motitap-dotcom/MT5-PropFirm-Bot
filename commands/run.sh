#!/bin/bash
# Replicate the EXACT sequence that worked at 12:18:18
echo "=== FIX AutoTrading $(date -u) ==="
export DISPLAY=:99

WIN_ID=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
echo "Window: $WIN_ID"

# This exact sequence worked before:
xdotool windowfocus --sync "$WIN_ID" 2>/dev/null
sleep 1
xdotool windowactivate --sync "$WIN_ID" 2>/dev/null
sleep 1
xdotool key --window "$WIN_ID" --clearmodifiers ctrl+e 2>/dev/null
echo "Sent Ctrl+E with --window flag"
sleep 5

# Check
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
echo "Last 5 lines:"
tail -5 "$EALOG" 2>&1

echo "=== DONE $(date -u) ==="
