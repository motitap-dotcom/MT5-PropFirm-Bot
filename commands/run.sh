#!/bin/bash
# Fix AutoTrading by clicking the button with xdotool
export DISPLAY=:99
export WINEPREFIX=/root/.wine

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"

echo "=== TIME: $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

# Install xdotool if needed
apt-get install -y -qq xdotool > /dev/null 2>&1

# Make sure MT5 is running
echo "=== MT5 Status ==="
ps aux | grep terminal64 | grep -v grep

# Method 1: Try Ctrl+E (AutoTrading toggle shortcut in MT5)
echo ""
echo "=== Pressing Ctrl+E to toggle AutoTrading ==="
# Find MT5 window
MT5_WIN=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
if [ -z "$MT5_WIN" ]; then
    MT5_WIN=$(xdotool search --name "terminal64" 2>/dev/null | head -1)
fi
if [ -z "$MT5_WIN" ]; then
    MT5_WIN=$(xdotool search --class "" 2>/dev/null | head -1)
fi

echo "MT5 Window ID: $MT5_WIN"

if [ -n "$MT5_WIN" ]; then
    # Focus the window
    xdotool windowactivate "$MT5_WIN" 2>/dev/null
    sleep 1

    # Send Ctrl+E (AutoTrading toggle)
    xdotool key --window "$MT5_WIN" ctrl+e 2>/dev/null
    echo "Sent Ctrl+E"
    sleep 2

    # Send it again just to make sure (if it was ON, first press turns OFF, second turns ON)
    # Actually let's not double-toggle, let's check the log first
fi

# Method 2: Also try clicking the AutoTrading button position (usually near top toolbar)
echo ""
echo "=== Taking screenshot for debug ==="
import -window root /tmp/mt5_screen.png 2>/dev/null || true
if [ -f /tmp/mt5_screen.png ]; then
    echo "Screenshot saved to /tmp/mt5_screen.png"
    ls -la /tmp/mt5_screen.png
fi

# List all windows
echo ""
echo "=== All X windows ==="
xdotool search --name "" 2>/dev/null | while read wid; do
    name=$(xdotool getwindowname "$wid" 2>/dev/null)
    echo "  Window $wid: $name"
done

# Wait and check if AutoTrading is now enabled
echo ""
echo "=== Waiting 15s then checking EA log ==="
sleep 15

LOG_FILE="$MT5_BASE/MQL5/Logs/$(date -u +%Y%m%d).log"
echo ""
echo "=== Last 20 lines of EA log ==="
tail -20 "$LOG_FILE" 2>/dev/null

# Check specifically for auto trading errors
echo ""
echo "=== Any remaining auto trading errors in last 30 seconds? ==="
tail -30 "$LOG_FILE" 2>/dev/null | grep -i "auto trading\|10027" || echo "No auto trading errors found!"

echo ""
echo "DONE $(date)"
