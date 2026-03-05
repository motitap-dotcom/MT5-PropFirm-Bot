#!/bin/bash
# =============================================================
# Fix #8: Check terminal log + fix profile + force EA load
# =============================================================

echo "=== FIX #8 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"

# ============================================
# STEP 1: Check terminal log (NOT EA log)
# ============================================
echo "--- STEP 1: Terminal logs ---"
echo "Terminal log dir:"
ls -la "${MT5_BASE}/logs/" 2>/dev/null | tail -10
echo ""

TERM_LOG=$(ls -t "${MT5_BASE}/logs/"*.log 2>/dev/null | head -1)
if [ -f "$TERM_LOG" ]; then
    echo "Latest terminal log: $TERM_LOG"
    iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | tail -50
fi
echo ""

# Check journal logs too
echo "Journal dir:"
ls -la "${MT5_BASE}/MQL5/Logs/" 2>/dev/null
echo ""

# ============================================
# STEP 2: Check profile/chart config
# ============================================
echo "--- STEP 2: Chart profiles ---"
echo "Profiles dir:"
ls -laR "${MT5_BASE}/profiles/" 2>/dev/null | head -20
echo ""

# Check the default chart template
echo "Default profile charts:"
find "${MT5_BASE}/profiles" -name "*.chr" 2>/dev/null | head -10
for chr in $(find "${MT5_BASE}/profiles" -name "*.chr" 2>/dev/null | head -5); do
    echo ""
    echo "=== $chr ==="
    grep -i "expert\|EA\|PropFirmBot\|autotrading" "$chr" 2>/dev/null | head -10
done
echo ""

# ============================================
# STEP 3: Check .ex5 exists and is valid
# ============================================
echo "--- STEP 3: EA file check ---"
ls -la "$EA_DIR/" 2>/dev/null | head -15
echo ""
echo ".ex5 file:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
file "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
echo ""

# ============================================
# STEP 4: Kill MT5 and fix
# ============================================
echo "--- STEP 4: Kill MT5 ---"
pkill -9 wineserver 2>/dev/null || true
pkill -9 -f "wine" 2>/dev/null || true
sleep 5

# Force delete saved state
find /root/.wine -name "PropFirmBot_AccountState.dat" -delete 2>/dev/null

# Remove old journal entry for today
echo ""

# ============================================
# STEP 5: Check if chart profile has EA, if not add it
# ============================================
echo "--- STEP 5: Ensure EA in chart profile ---"
DEFAULT_CHART=$(find "${MT5_BASE}/profiles" -name "chart01.chr" 2>/dev/null | head -1)
if [ -f "$DEFAULT_CHART" ]; then
    echo "Found chart: $DEFAULT_CHART"
    if grep -q "PropFirmBot" "$DEFAULT_CHART" 2>/dev/null; then
        echo "EA already in chart profile"
    else
        echo "EA NOT in chart - adding..."
        # Add EA configuration to chart
        cat >> "$DEFAULT_CHART" << 'CHREOF'
<expert>
name=PropFirmBot\PropFirmBot
path=PropFirmBot\PropFirmBot.ex5
expertmode=1
<inputs>
</inputs>
</expert>
CHREOF
        echo "EA added to chart"
    fi
    echo "Chart content:"
    cat "$DEFAULT_CHART"
else
    echo "No chart profile found!"
    echo "Creating default profile with EA..."
    mkdir -p "${MT5_BASE}/profiles/default"
    cat > "${MT5_BASE}/profiles/default/chart01.chr" << 'CHREOF'
<chart>
id=1
symbol=EURUSD
period=15
leftpos=0
digits=5
scale=4
graph=1
fore=0
grid=0
volume=0
scroll=1
shift=1
ohlc=1
askline=0
days=0
descriptions=0
shift_size=20
fixed_pos=0
window_left=0
window_top=0
window_right=1280
window_bottom=1024
window_type=3
background_color=0
foreground_color=16777215
barup_color=65280
bardown_color=255
bullcandle_color=65280
bearcandle_color=255
chartline_color=65280
volumes_color=3329330
grid_color=10061943
askline_color=255
stops_color=255
<expert>
name=PropFirmBot\PropFirmBot
path=PropFirmBot\PropFirmBot.ex5
expertmode=1
<inputs>
</inputs>
</expert>
</chart>
CHREOF
    echo "Created chart with EA"
fi
echo ""

# ============================================
# STEP 6: Restart MT5
# ============================================
echo "--- STEP 6: Restart MT5 ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

cd "$MT5_BASE"
nohup wine "$MT5_BASE/terminal64.exe" /portable > /tmp/mt5_stdout.log 2>&1 &
echo "MT5 starting... (waiting 50 sec)"
sleep 50

# ============================================
# STEP 7: Check results
# ============================================
echo "--- STEP 7: Results ---"

echo "Wine processes:"
pgrep -a wineserver 2>/dev/null
echo ""

echo "Network:"
ss -tnp | grep "wineserver" | head -3
echo ""

echo "NEW EA Log:"
NEW_LOG=$(ls -t "${MT5_BASE}/MQL5/Logs/"*.log 2>/dev/null | grep -v ".old" | head -1)
if [ -f "$NEW_LOG" ]; then
    SIZE=$(stat -c%s "$NEW_LOG")
    echo "Log: $NEW_LOG ($SIZE bytes)"
    iconv -f UTF-16LE -t UTF-8 "$NEW_LOG" 2>/dev/null | head -40
else
    echo "STILL no EA log!"
fi
echo ""

echo "Terminal log (new entries):"
TERM_LOG=$(ls -t "${MT5_BASE}/logs/"*.log 2>/dev/null | head -1)
if [ -f "$TERM_LOG" ]; then
    iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | grep -i "expert\|EA\|error\|failed\|PropFirmBot\|chart\|started" | tail -20
fi
echo ""

echo "Relay:"
pgrep -f "telegram_relay" > /dev/null && echo "Running" || echo "NOT running"
echo ""

echo "=== DONE - $(date) ==="
