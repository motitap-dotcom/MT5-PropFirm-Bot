#!/bin/bash
# Quick check: is AutoTrading working after UTF-16 fix + Ctrl+E?
echo "=== CHECK AutoTrading $(date -u) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# 1. MT5 status
echo "[1] MT5:"
pgrep -f terminal64 > /dev/null && echo "RUNNING" || echo "NOT RUNNING"
echo ""

# 2. ALL EA log entries from today (most recent)
echo "[2] EA log (all from today):"
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$EALOG" ]; then
    echo "File: $EALOG ($(wc -l < "$EALOG" 2>/dev/null) lines)"
    # Show last 30 lines to get the latest activity
    tail -30 "$EALOG" 2>&1
fi
echo ""

# 3. Terminal log (try different encoding)
echo "[3] Terminal log:"
TLOG=$(ls -t "$MT5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$TLOG" ]; then
    echo "File: $TLOG"
    # Try plain first, then iconv
    tail -20 "$TLOG" 2>&1
fi
echo ""

# 4. Try one more approach: use xdotool to take screenshot for debugging
echo "[4] Window list:"
export DISPLAY=:99
xdotool search --name "" 2>/dev/null | while read w; do
    name=$(xdotool getwindowname "$w" 2>/dev/null)
    echo "  $w: $name"
done
echo ""

# 5. Try clicking AutoTrading button via menu: Tools > Options > Expert Advisors
# Actually, just try clicking the toolbar button area
echo "[5] Sending Ctrl+E again..."
WIN_ID=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
[ -z "$WIN_ID" ] && WIN_ID=$(xdotool search --name "terminal64" 2>/dev/null | head -1)
[ -z "$WIN_ID" ] && WIN_ID=$(xdotool search --name "" 2>/dev/null | head -1)

if [ -n "$WIN_ID" ]; then
    echo "Window: $WIN_ID ($(xdotool getwindowname "$WIN_ID" 2>/dev/null))"
    xdotool windowfocus "$WIN_ID" 2>/dev/null
    sleep 1
    # Try both ctrl+e and Ctrl+E
    xdotool key --window "$WIN_ID" ctrl+e 2>/dev/null
    echo "Sent Ctrl+E"

    # Also try clicking the AutoTrading button
    # In MT5 default layout, the Algo Trading button is in the toolbar
    # Usually around x=57, y=44 (second button from left in standard toolbar)
    echo "Trying to click AutoTrading button at various positions..."
    for x in 48 57 66 80 95 110 130 150 170; do
        xdotool mousemove --window "$WIN_ID" $x 44 2>/dev/null
        xdotool click --window "$WIN_ID" 1 2>/dev/null
        sleep 0.2
    done
    echo "Clicked toolbar area"
fi
echo ""

# 6. Wait and check log again
echo "[6] Waiting 10 seconds..."
sleep 10

EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$EALOG" ]; then
    echo "EA log (last 10 lines):"
    tail -10 "$EALOG" 2>&1
fi

echo ""
echo "=== DONE $(date -u) ==="
