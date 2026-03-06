#!/bin/bash
# Try ALL approaches to enable AutoTrading
echo "=== FIX AutoTrading - ALL methods $(date -u) ==="
export DISPLAY=:99
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# List ALL FundedNext windows with their IDs
echo "[1] All FundedNext windows:"
ALL_WINS=$(xdotool search --name "FundedNext" 2>/dev/null)
echo "$ALL_WINS" | while read w; do
    echo "  $w: $(xdotool getwindowname "$w" 2>/dev/null) - $(xdotool getwindowgeometry "$w" 2>/dev/null)"
done
echo ""

# Try Ctrl+E on EACH window individually and check after each
echo "[2] Trying Ctrl+E on each window..."
EALOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)

for WIN in $ALL_WINS; do
    WNAME=$(xdotool getwindowname "$WIN" 2>/dev/null)
    # Only target the main window (not the chart sub-window)
    if echo "$WNAME" | grep -q "EURUSD"; then
        echo "  Skipping chart window: $WIN ($WNAME)"
        continue
    fi
    echo "  Trying window $WIN: $WNAME"
    xdotool windowfocus --sync "$WIN" 2>/dev/null
    sleep 1
    xdotool windowactivate --sync "$WIN" 2>/dev/null
    sleep 1
    xdotool key --window "$WIN" --clearmodifiers ctrl+e 2>/dev/null
    sleep 3
    # Check if it worked
    LAST_LINE=$(tail -1 "$EALOG" 2>/dev/null)
    echo "  Log: $LAST_LINE"
    if echo "$LAST_LINE" | grep -iq "enabled"; then
        echo "  *** SUCCESS! AutoTrading enabled ***"
        break
    fi
done
echo ""

# Method 2: Try using xte (xautomation)
echo "[3] Installing xautomation..."
apt-get install -y xautomation 2>/dev/null | tail -1
echo "Trying xte..."
MAIN_WIN=$(echo "$ALL_WINS" | head -1)
xdotool windowfocus --sync "$MAIN_WIN" 2>/dev/null
sleep 1
xte 'keydown Control_L' 'key e' 'keyup Control_L' 2>/dev/null && echo "xte sent Ctrl+E" || echo "xte failed"
sleep 3
tail -2 "$EALOG" 2>&1
echo ""

# Method 3: Try clicking the Algo Trading button position
echo "[4] Clicking toolbar positions..."
# In MT5, Algo Trading is the green/red button in toolbar, usually around x=20-80, y=40
MAIN_WIN=$(echo "$ALL_WINS" | head -1)
xdotool windowfocus --sync "$MAIN_WIN" 2>/dev/null
sleep 1
# Get window position
WIN_X=$(xdotool getwindowgeometry "$MAIN_WIN" 2>/dev/null | grep Position | sed 's/.*Position: \([0-9]*\),.*/\1/')
WIN_Y=$(xdotool getwindowgeometry "$MAIN_WIN" 2>/dev/null | grep Position | sed 's/.*,\([0-9]*\).*/\1/')
echo "Window at: $WIN_X,$WIN_Y"

# Click at various toolbar positions (toolbar is about 26px tall, starts at window top)
# AutoTrading button could be at various x positions
for x in 30 50 70 90 110 130 150 170 190 210 230 250; do
    ABS_X=$((WIN_X + x))
    ABS_Y=$((WIN_Y + 38))
    xdotool mousemove $ABS_X $ABS_Y 2>/dev/null
    sleep 0.1
    xdotool click 1 2>/dev/null
    sleep 0.5
done
echo "Clicked toolbar area"
sleep 3
echo "Log after clicks:"
tail -3 "$EALOG" 2>&1
echo ""

# Method 4: Screenshot for debugging
echo "[5] Taking screenshot..."
import -window root /tmp/mt5_screenshot.png 2>/dev/null && echo "Screenshot saved to /tmp/mt5_screenshot.png" || echo "import not available"
# Try scrot
scrot /tmp/mt5_screenshot.png 2>/dev/null && echo "scrot screenshot saved" || echo "scrot not available"

echo "=== DONE $(date -u) ==="
