#!/bin/bash
# =============================================================
# Fix #14: Use xdotool to attach EA via MT5 GUI
# =============================================================

echo "=== FIX #14 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# ============================================
# STEP 1: Check if MT5 is already running
# ============================================
echo "--- STEP 1: Check MT5 ---"
if ss -tnp | grep -q "wineserver"; then
    echo "MT5 is running"
else
    echo "MT5 not running - starting..."
    cd "$MT5_BASE"
    nohup wine "$MT5_BASE/terminal64.exe" /portable > /tmp/mt5_stdout.log 2>&1 &
    sleep 30
fi
echo ""

# ============================================
# STEP 2: Install xdotool if needed
# ============================================
echo "--- STEP 2: Install xdotool ---"
which xdotool > /dev/null 2>&1 || apt-get install -y -qq xdotool > /dev/null 2>&1
echo "xdotool: $(which xdotool)"
echo ""

# ============================================
# STEP 3: Find MT5 window
# ============================================
echo "--- STEP 3: Find MT5 window ---"
# List all windows
echo "All windows:"
xdotool search --name "" 2>/dev/null | while read wid; do
    name=$(xdotool getwindowname "$wid" 2>/dev/null)
    [ -n "$name" ] && echo "  $wid: $name"
done | head -20
echo ""

# Find MT5 window
MT5_WID=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
if [ -z "$MT5_WID" ]; then
    MT5_WID=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
fi
if [ -z "$MT5_WID" ]; then
    MT5_WID=$(xdotool search --name "terminal" 2>/dev/null | head -1)
fi

echo "MT5 Window ID: $MT5_WID"
if [ -n "$MT5_WID" ]; then
    echo "Window name: $(xdotool getwindowname "$MT5_WID" 2>/dev/null)"
fi
echo ""

# ============================================
# STEP 4: Attach EA using keyboard shortcut
# ============================================
echo "--- STEP 4: Attach EA via GUI ---"
if [ -n "$MT5_WID" ]; then
    # Focus the MT5 window
    xdotool windowactivate --sync "$MT5_WID" 2>/dev/null
    sleep 1

    # Method 1: Use Ctrl+N to open Navigator, then navigate to Expert
    echo "Opening Navigator (Ctrl+N)..."
    xdotool key --window "$MT5_WID" ctrl+n
    sleep 2

    # Take a screenshot for debugging
    if command -v import > /dev/null 2>&1; then
        import -window root /tmp/mt5_screenshot.png 2>/dev/null
    elif command -v scrot > /dev/null 2>&1; then
        scrot /tmp/mt5_screenshot.png 2>/dev/null
    fi

    # Method 2: Try the Insert key shortcut (Insert attaches EA from Navigator)
    # First, let's try a different approach - use the menu
    echo "Trying Insert menu > Expert Advisor..."

    # Actually, the most reliable method: use wmctrl or xdotool to send
    # the right sequence of events

    # For MT5, pressing F7 opens the EA properties if one is attached
    # Pressing Ctrl+E enables/disables auto-trading

    # Let me try: open the file menu to insert EA
    echo "Sending Alt+I (Insert menu)..."
    xdotool key --window "$MT5_WID" alt+i 2>/dev/null
    sleep 1

    # Alternative: try directly via F5 key (which opens the tester in some versions)
    # Or try the approach of navigating through the menu

    echo "Trying right-click approach..."
    # Get window geometry
    eval $(xdotool getwindowgeometry --shell "$MT5_WID" 2>/dev/null)
    echo "Window: ${WIDTH}x${HEIGHT}"

    # Right click on the chart area (center of window)
    CENTER_X=$((WIDTH / 2))
    CENTER_Y=$((HEIGHT / 2))
    echo "Right-clicking at $CENTER_X, $CENTER_Y"
    xdotool mousemove --window "$MT5_WID" $CENTER_X $CENTER_Y
    sleep 0.5
    xdotool click --window "$MT5_WID" 3  # Right click
    sleep 1

    # In the context menu, "Expert Advisor" option should be there
    # Navigate with arrow keys

    echo ""
    echo "Taking screenshot..."
    xdotool key Escape  # Close menu first
    sleep 0.5
else
    echo "No MT5 window found!"
fi
echo ""

# ============================================
# STEP 5: Alternative - check if the old scripts know how to attach EA
# ============================================
echo "--- STEP 5: Check existing VPS scripts ---"
echo "relay/daemon.sh:"
head -50 /root/MT5-PropFirm-Bot/relay/daemon.sh 2>/dev/null || echo "Not found"
echo ""

echo "scripts/fix_and_start.sh:"
head -50 /root/MT5-PropFirm-Bot/scripts/fix_and_start.sh 2>/dev/null || echo "Not found"
echo ""

echo "management/server.py (first 30 lines):"
head -30 /root/MT5-PropFirm-Bot/management/server.py 2>/dev/null || echo "Not found"
echo ""

# ============================================
# STEP 6: Check current state
# ============================================
echo "--- STEP 6: Current state ---"
echo "EA Log:"
ls -la "${MT5_BASE}/MQL5/Logs/20260305"* 2>/dev/null || echo "No today's log"
echo ""

echo "Terminal log (last 5):"
TERM_LOG=$(ls -t "${MT5_BASE}/logs/"*.log 2>/dev/null | head -1)
[ -f "$TERM_LOG" ] && iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | tail -5
echo ""

echo "=== DONE - $(date) ==="
