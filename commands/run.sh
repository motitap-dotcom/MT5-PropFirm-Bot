#!/bin/bash
# Fix: Send Ctrl+E to the correct MT5 window to enable AutoTrading
echo "=== FIX AutoTrading - correct window $(date -u) ==="

export DISPLAY=:99
export WINEPREFIX=/root/.wine
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. Find the correct MT5 main window by name
echo "[1] Finding MT5 window by name 'FundedNext'..."
WIN_ID=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
echo "FundedNext window: $WIN_ID"

if [ -z "$WIN_ID" ]; then
    echo "Trying '11797849'..."
    WIN_ID=$(xdotool search --name "11797849" 2>/dev/null | head -1)
fi

if [ -z "$WIN_ID" ]; then
    echo "Trying 'MetaTrader'..."
    WIN_ID=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
fi

echo "Target window: $WIN_ID"
if [ -n "$WIN_ID" ]; then
    echo "Name: $(xdotool getwindowname "$WIN_ID" 2>/dev/null)"
    xdotool getwindowgeometry "$WIN_ID" 2>/dev/null
fi
echo ""

# 2. Focus and send Ctrl+E
echo "[2] Sending Ctrl+E to toggle AutoTrading..."
if [ -n "$WIN_ID" ]; then
    # Focus the window
    xdotool windowfocus --sync "$WIN_ID" 2>/dev/null
    sleep 1
    xdotool windowactivate --sync "$WIN_ID" 2>/dev/null
    sleep 1

    # Send Ctrl+E
    xdotool key --window "$WIN_ID" --clearmodifiers ctrl+e 2>/dev/null
    echo "Sent Ctrl+E to window $WIN_ID"
    sleep 3

    # Check log immediately for "automated trading" message
    EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
    echo "Log after Ctrl+E:"
    tail -5 "$EALOG" 2>&1
    echo ""

    # If still disabled, try sending it again
    if tail -3 "$EALOG" 2>&1 | grep -q "disabled"; then
        echo "Still disabled, trying again..."
        xdotool key --window "$WIN_ID" --clearmodifiers ctrl+e 2>/dev/null
        sleep 2
        tail -3 "$EALOG" 2>&1
    fi
else
    echo "NO MT5 WINDOW FOUND!"
fi
echo ""

# 3. Also try: find ALL windows named FundedNext and send Ctrl+E to each
echo "[3] Sending Ctrl+E to ALL FundedNext windows..."
for wid in $(xdotool search --name "FundedNext" 2>/dev/null); do
    wname=$(xdotool getwindowname "$wid" 2>/dev/null)
    echo "  Window $wid: $wname"
    xdotool windowfocus --sync "$wid" 2>/dev/null
    sleep 0.5
    xdotool key --window "$wid" --clearmodifiers ctrl+e 2>/dev/null
    sleep 1
done
echo ""

# 4. Wait for next bar and check
echo "[4] Waiting 30 seconds for next trade attempt..."
sleep 30

EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
echo "EA log (last 15 lines):"
tail -15 "$EALOG" 2>&1

echo ""
echo "=== DONE $(date -u) ==="
