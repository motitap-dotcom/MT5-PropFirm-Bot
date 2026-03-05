#!/bin/bash
# =============================================================
# Fix #16: Attach EA to chart using xdotool GUI automation
# Since MT5 on Wine doesn't auto-load EA from config files,
# we use xdotool to simulate dragging EA onto chart via Navigator
# =============================================================

echo "=== FIX #16 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine
export WINEDEBUG=-all

# ============================================
# STEP 0: Ensure xdotool is available
# ============================================
echo "--- STEP 0: Check xdotool ---"
which xdotool 2>/dev/null || apt-get install -y xdotool 2>/dev/null
echo ""

# ============================================
# STEP 1: Check current state
# ============================================
echo "--- STEP 1: Current MT5 state ---"
if pgrep -f terminal64 > /dev/null; then
    echo "MT5 is RUNNING"
else
    echo "MT5 is NOT running - starting it..."
    cd "$MT5_BASE"
    DISPLAY=:99 nohup wine terminal64.exe >/dev/null 2>&1 &
    echo "Waiting 20s for MT5 to start..."
    sleep 20
    if pgrep -f terminal64 > /dev/null; then
        echo "MT5 started successfully"
    else
        echo "MT5 FAILED to start"
        exit 1
    fi
fi

# Check if EA is already loaded
EA_LOG="${MT5_BASE}/MQL5/Logs/20260305.log"
if [ -f "$EA_LOG" ]; then
    LAST_EA=$(iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | tail -3)
    echo "EA log exists - last lines:"
    echo "$LAST_EA"
else
    echo "No EA log for today - EA NOT loaded"
fi
echo ""

# ============================================
# STEP 2: List all MT5 windows
# ============================================
echo "--- STEP 2: MT5 windows ---"
xdotool search --name "MetaTrader" 2>/dev/null
xdotool search --name "EURUSD" 2>/dev/null
xdotool search --name "terminal64" 2>/dev/null
# Get all windows
echo "All windows:"
wmctrl -l 2>/dev/null || xdotool search --name "" 2>/dev/null | while read wid; do
    echo "  $wid: $(xdotool getwindowname $wid 2>/dev/null)"
done
echo ""

# ============================================
# STEP 3: Find the MT5 main window
# ============================================
echo "--- STEP 3: Find MT5 window ---"
# Try multiple patterns
MT5_WIN=$(xdotool search --name "MetaTrader" 2>/dev/null | head -1)
if [ -z "$MT5_WIN" ]; then
    MT5_WIN=$(xdotool search --name "EURUSD" 2>/dev/null | head -1)
fi
if [ -z "$MT5_WIN" ]; then
    MT5_WIN=$(xdotool search --name "terminal64" 2>/dev/null | head -1)
fi
if [ -z "$MT5_WIN" ]; then
    # Try by class
    MT5_WIN=$(xdotool search --class "Wine" 2>/dev/null | head -1)
fi

if [ -z "$MT5_WIN" ]; then
    echo "ERROR: Cannot find MT5 window!"
    echo "Listing all X windows:"
    xdotool search --name "" 2>/dev/null | head -20 | while read wid; do
        echo "  $wid: $(xdotool getwindowname $wid 2>/dev/null)"
    done
    exit 1
fi
echo "MT5 window ID: $MT5_WIN"
echo "Window name: $(xdotool getwindowname $MT5_WIN 2>/dev/null)"
echo ""

# ============================================
# STEP 4: Focus MT5 and use keyboard to open Navigator + attach EA
# ============================================
echo "--- STEP 4: Attach EA via keyboard automation ---"

# Focus the MT5 window
xdotool windowactivate --sync $MT5_WIN 2>/dev/null
sleep 1
xdotool windowfocus --sync $MT5_WIN 2>/dev/null
sleep 1

echo "Step 4a: Open Navigator panel (Ctrl+N)"
xdotool key --window $MT5_WIN ctrl+n
sleep 2

echo "Step 4b: Try Insert key to open EA insertion dialog"
# In MT5, with Navigator focused, we can try the Insert Expert method
# First, let's try the menu approach: View -> Navigator
xdotool key --window $MT5_WIN ctrl+n
sleep 1

# Alternative: Use the menu to insert EA
echo "Step 4c: Try menu Insert -> Expert Advisors"
# In MT5: Insert menu -> Expert Advisors -> From File/List
# But Wine menu interaction is unreliable

# Better approach: Use MT5 command line startup with EA
echo ""
echo "--- STEP 4d: Trying chart profile approach ---"

# First, check current chart profile
echo "Current chart01.chr:"
ls -la "${MT5_BASE}/MQL5/Profiles/Charts/Default/" 2>/dev/null
cat "${MT5_BASE}/MQL5/Profiles/Charts/Default/chart01.chr" 2>/dev/null | head -30
echo ""

# Check if there's an expert section already
echo "Expert section in chart profile:"
grep -i "expert" "${MT5_BASE}/MQL5/Profiles/Charts/Default/chart01.chr" 2>/dev/null || echo "(none found - binary/UTF-16)"
iconv -f UTF-16LE -t UTF-8 "${MT5_BASE}/MQL5/Profiles/Charts/Default/chart01.chr" 2>/dev/null | grep -i -A5 "expert" || echo "(no expert section)"
echo ""

# ============================================
# STEP 5: Try the PROPER method - write chart template with EA
# ============================================
echo "--- STEP 5: Create chart template with EA ---"

# First let's see what encoding chart files use
echo "File type of chart01.chr:"
file "${MT5_BASE}/MQL5/Profiles/Charts/Default/chart01.chr" 2>/dev/null
echo ""
echo "Hex dump first 20 bytes:"
xxd "${MT5_BASE}/MQL5/Profiles/Charts/Default/chart01.chr" 2>/dev/null | head -3
echo ""

# Read the full chart profile to understand its format
echo "Full chart01.chr content (converted):"
iconv -f UTF-16LE -t UTF-8 "${MT5_BASE}/MQL5/Profiles/Charts/Default/chart01.chr" 2>/dev/null
echo ""
echo "=== END chart01.chr ==="
echo ""

# Also check if there are other chart profiles
echo "All chart profile files:"
find "${MT5_BASE}/MQL5/Profiles/" -name "*.chr" 2>/dev/null
echo ""

# Check templates too
echo "Templates:"
find "${MT5_BASE}/MQL5/Profiles/Templates/" -name "*.tpl" 2>/dev/null
echo ""

# Check the terminal log for expert loading clues
echo "--- STEP 6: Terminal log (expert-related) ---"
TERM_LOG=$(ls -t "${MT5_BASE}/logs/"*.log 2>/dev/null | head -1)
if [ -f "$TERM_LOG" ]; then
    echo "Log file: $TERM_LOG"
    iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | grep -i "expert\|EA\|PropFirm\|loaded\|chart" | tail -20
fi
echo ""

# Also check common.ini for StartUp section
echo "--- STEP 7: common.ini StartUp section ---"
iconv -f UTF-16LE -t UTF-8 "${MT5_BASE}/config/common.ini" 2>/dev/null | head -50
echo ""

echo "=== DONE - $(date) ==="
