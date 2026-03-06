#!/bin/bash
# Fix AutoTrading - send Ctrl+E to correct MT5 window
export DISPLAY=:99
export WINEPREFIX=/root/.wine

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "=== TIME: $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

# Find the CORRECT MT5 window (the chart window with EURUSD)
echo "=== Finding MT5 window ==="
MT5_WIN=$(xdotool search --name "FundedNext" 2>/dev/null | tail -1)
echo "MT5 main window: $MT5_WIN"

if [ -z "$MT5_WIN" ]; then
    echo "ERROR: Cannot find MT5 window!"
    exit 1
fi

WINNAME=$(xdotool getwindowname "$MT5_WIN" 2>/dev/null)
echo "Window name: $WINNAME"

# Focus and bring to front
xdotool windowactivate --sync "$MT5_WIN" 2>/dev/null
sleep 2
xdotool windowfocus --sync "$MT5_WIN" 2>/dev/null
sleep 1

# Send Ctrl+E to toggle AutoTrading
echo ""
echo "=== Sending Ctrl+E ==="
xdotool key --window "$MT5_WIN" --clearmodifiers ctrl+e
echo "Ctrl+E sent!"
sleep 3

# Verify by checking if next trade attempt works
echo ""
echo "=== Checking EA log for trade result ==="
sleep 10

LOG_FILE="$MT5_BASE/MQL5/Logs/$(date -u +%Y%m%d).log"
echo "Last 15 lines:"
tail -15 "$LOG_FILE" 2>/dev/null

# Check for success or still disabled
echo ""
echo "=== Checking auto trading status ==="
# Look at very latest entries
tail -5 "$LOG_FILE" 2>/dev/null | grep -i "auto trading\|10027\|OrderSend\|success\|done\|TRADE" && echo "Still has issues" || echo "No recent auto trading errors"

# Also check terminal.ini and startup.ini for reference
echo ""
echo "=== terminal.ini content ==="
cat "$MT5_BASE/config/terminal.ini" 2>/dev/null | head -30

echo ""
echo "=== startup.ini content ==="
cat "$MT5_BASE/config/startup.ini" 2>/dev/null | head -30

# Check all chart profiles for EA settings
echo ""
echo "=== Chart profiles ==="
find "$MT5_BASE/Profiles" -name "*.chr" 2>/dev/null | while read f; do
    echo "--- $f ---"
    cat "$f" 2>/dev/null | head -30
done

echo ""
echo "DONE $(date)"
