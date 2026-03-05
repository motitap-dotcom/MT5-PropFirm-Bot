#!/bin/bash
# =============================================================
# Fix #19: Force EA load via MT5 /config: command line parameter
# Previous attempts: chart01.chr + common.ini [StartUp] - EA didn't load
# Now: Use explicit /config: startup ini with EA specification
# =============================================================

echo "=== FIX #19 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine
export WINEDEBUG=-all

# ============================================
# STEP 1: Stop MT5
# ============================================
echo "--- STEP 1: Stop MT5 ---"
killall terminal64.exe 2>/dev/null
sleep 2
pkill -9 -f terminal64 2>/dev/null
sleep 3
echo "MT5 stopped: $(pgrep -f terminal64 > /dev/null && echo 'STILL RUNNING' || echo 'OK')"
echo ""

# ============================================
# STEP 2: Create a dedicated startup config
# ============================================
echo "--- STEP 2: Create startup config ---"

# Create startup.ini in MT5 config directory (plain ASCII, just like common.ini)
cat > "${MT5_BASE}/config/startup.ini" << 'INI_EOF'
[StartUp]
Expert=PropFirmBot\PropFirmBot
ExpertParameters=
Symbol=EURUSD
Period=M15
[Experts]
AllowLiveTrading=1
AllowDllImport=0
Enabled=1
Account=11797849
Profile=0
AllowWebRequest=1
WebRequestUrl1=https://api.telegram.org
INI_EOF

echo "startup.ini created:"
cat "${MT5_BASE}/config/startup.ini"
echo ""

# ============================================
# STEP 3: Ensure chart profile has EA
# ============================================
echo "--- STEP 3: Verify chart profile ---"
echo "chart01.chr exists: $([ -f '${MT5_BASE}/MQL5/Profiles/Charts/Default/chart01.chr' ] && echo 'YES' || echo 'NO')"
echo ""

# ============================================
# STEP 4: Start MT5 with /config: parameter
# ============================================
echo "--- STEP 4: Start MT5 with /config ---"
cd "$MT5_BASE"

# Method 1: Use /config: to force startup with our ini
echo "Starting MT5 with /config:config\\startup.ini ..."
DISPLAY=:99 nohup wine terminal64.exe "/config:config\\startup.ini" >/dev/null 2>&1 &
MT5_PID=$!
echo "MT5 PID: $MT5_PID"
echo "Waiting 45 seconds for MT5 to fully initialize..."
sleep 45

if pgrep -f terminal64 > /dev/null; then
    echo "MT5 is RUNNING"
else
    echo "MT5 FAILED to start with /config - trying without..."
    DISPLAY=:99 nohup wine terminal64.exe >/dev/null 2>&1 &
    sleep 30
fi
echo ""

# ============================================
# STEP 5: Check if EA loaded
# ============================================
echo "--- STEP 5: Check EA status ---"

# Get latest terminal log
TERM_LOG=$(ls -t "${MT5_BASE}/logs/"*.log 2>/dev/null | head -1)
echo "Latest log: $TERM_LOG"
echo ""

echo "Terminal log - NEW entries (after 13:00):"
iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | grep -E "1[3-9]:" | tail -20
echo ""

echo "Expert-related entries (ALL):"
iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | grep -i "expert\|PropFirm\|loaded\|removed\|error\|fail" | tail -15
echo ""

# Check EA log
EA_LOG="${MT5_BASE}/MQL5/Logs/20260305.log"
if [ -f "$EA_LOG" ]; then
    echo "EA LOG EXISTS: $(stat -c%s "$EA_LOG") bytes"
    echo "Content:"
    iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | tail -20
else
    echo "NO EA LOG - checking other dates:"
    ls -la "${MT5_BASE}/MQL5/Logs/" 2>/dev/null | tail -5
fi
echo ""

# Check window title for EA indicator
echo "--- STEP 6: Window info ---"
MT5_WIN=$(xdotool search --name "FundedNext" 2>/dev/null | head -1)
echo "MT5 window: $MT5_WIN"
echo "Title: $(xdotool getwindowname $MT5_WIN 2>/dev/null)"
echo ""

# ============================================
# STEP 7: If EA still not loaded, try xdotool GUI automation
# ============================================
echo "--- STEP 7: GUI automation attempt ---"

# Check if expert is loaded by looking for recent expert log entry
EXPERT_LOADED=$(iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | grep "expert.*loaded" | tail -1 | awk '{print $3}' | cut -d. -f1)
CURRENT_HOUR=$(date +%H)

if [ -n "$EXPERT_LOADED" ]; then
    EXPERT_HOUR=$(echo "$EXPERT_LOADED" | cut -d: -f1)
    echo "Last expert loaded at: $EXPERT_LOADED (current: $(date +%H:%M))"
    # Check if loaded within the last hour
    if [ "$EXPERT_HOUR" -ge "$((CURRENT_HOUR - 1))" ] 2>/dev/null; then
        echo "EA WAS LOADED RECENTLY - SUCCESS!"
    else
        echo "EA loaded long ago - trying xdotool..."
    fi
else
    echo "No expert loaded entry found - trying xdotool..."
fi

# Use xdotool to navigate MT5 GUI and attach EA
if [ -n "$MT5_WIN" ]; then
    echo ""
    echo "Activating MT5 window..."
    xdotool windowactivate --sync $MT5_WIN 2>/dev/null
    sleep 2

    # Try right-click on chart to get context menu
    echo "Right-clicking center of chart..."
    # Get window geometry
    eval $(xdotool getwindowgeometry --shell $MT5_WIN 2>/dev/null)
    CENTER_X=$((WIDTH / 2))
    CENTER_Y=$((HEIGHT / 2))
    echo "Window size: ${WIDTH}x${HEIGHT}, center: ${CENTER_X},${CENTER_Y}"

    # Click in the chart area first (to make sure chart is focused)
    xdotool mousemove --window $MT5_WIN $CENTER_X $CENTER_Y
    sleep 0.5
    xdotool click --window $MT5_WIN 1  # Left click
    sleep 1

    # Open Navigator with Ctrl+N
    echo "Opening Navigator (Ctrl+N)..."
    xdotool key --window $MT5_WIN ctrl+n
    sleep 2

    # Take a screenshot to see what's happening
    echo "Taking screenshot..."
    import -window root -display :99 /tmp/mt5_screenshot.png 2>/dev/null || \
    xwd -root -display :99 -out /tmp/mt5_screenshot.xwd 2>/dev/null
    echo "Screenshot saved"

    # Try a different approach: use the Insert menu
    echo "Trying Insert menu..."
    xdotool key --window $MT5_WIN alt+i  # Alt+I for Insert menu
    sleep 1
    xdotool key --window $MT5_WIN Down   # First item
    sleep 0.5
    xdotool key --window $MT5_WIN Return  # Select
    sleep 2

    # Check again
    echo ""
    echo "After GUI automation - checking log..."
    iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | grep -i "expert\|PropFirm\|loaded" | tail -5
fi
echo ""

echo "=== DONE - $(date) ==="
