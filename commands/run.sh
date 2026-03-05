#!/bin/bash
# =============================================================
# Fix #9: Find correct chart profile location + restore EA
# =============================================================

echo "=== FIX #9 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"

# ============================================
# STEP 1: Find ALL chart/profile related files
# ============================================
echo "--- STEP 1: Search for chart/profile files ---"
echo "Looking for .chr files:"
find "$MT5_BASE" -name "*.chr" 2>/dev/null
echo ""

echo "Looking for chart-related dirs:"
find "$MT5_BASE" -type d -iname "*chart*" 2>/dev/null
find "$MT5_BASE" -type d -iname "*profile*" 2>/dev/null
find "$MT5_BASE" -type d -iname "*default*" 2>/dev/null
echo ""

echo "Looking for chart data files:"
find "$MT5_BASE" -name "*.chr" -o -name "*.chart" -o -name "chartwindow*" 2>/dev/null
echo ""

echo "MQL5/Profiles directory:"
ls -laR "$MT5_BASE/MQL5/Profiles/" 2>/dev/null || echo "Not found"
echo ""

echo "profiles/ directory:"
ls -laR "$MT5_BASE/profiles/" 2>/dev/null || echo "Not found"
echo ""

# Check if there's a history/charts path
echo "All directories in MT5_BASE:"
find "$MT5_BASE" -maxdepth 2 -type d 2>/dev/null | sort
echo ""

# ============================================
# STEP 2: Kill MT5 and set up proper profile
# ============================================
echo "--- STEP 2: Kill MT5 ---"
pkill -9 wineserver 2>/dev/null || true
pkill -9 -f "wine" 2>/dev/null || true
sleep 5

# Delete state
find /root/.wine -name "PropFirmBot_AccountState.dat" -delete 2>/dev/null

echo "--- STEP 3: Create chart profiles in ALL possible locations ---"

# Chart profile content
CHART_CONTENT='<chart>
id=1
symbol=EURUSD
period_type=0
period_size=15
digits=5
scale=4
graph=1
fore=0
grid=0
volume=0
scroll=1
shift=1
ohlc=1
one_click=0
one_click_btn=1
askline=0
days=0
descriptions=0
shift_size=20
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
expertmode=33
<inputs>
</inputs>
</expert>
</chart>
'

# Create in all possible locations
for dir in \
    "$MT5_BASE/profiles/default" \
    "$MT5_BASE/profiles/charts/default" \
    "$MT5_BASE/MQL5/Profiles/Charts/Default" \
    "$MT5_BASE/config/charts"; do
    mkdir -p "$dir"
    echo "$CHART_CONTENT" > "$dir/chart01.chr"
    echo "Created: $dir/chart01.chr"
done
echo ""

# ============================================
# STEP 4: Ensure common.ini has correct StartUp
# ============================================
echo "--- STEP 4: Verify common.ini ---"
grep "\[StartUp\]" "$MT5_BASE/config/common.ini" && echo "StartUp section present" || echo "StartUp MISSING!"
grep "Expert=" "$MT5_BASE/config/common.ini" || echo "Expert not set!"
echo ""

# ============================================
# STEP 5: Start MT5 and wait LONGER
# ============================================
echo "--- STEP 5: Start MT5 (waiting 90 sec) ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

cd "$MT5_BASE"
nohup wine "$MT5_BASE/terminal64.exe" /portable > /tmp/mt5_stdout.log 2>&1 &
echo "MT5 started, waiting 90 seconds..."
sleep 90

# ============================================
# STEP 6: Check results
# ============================================
echo "--- STEP 6: Results ---"

echo "Network:"
ss -tnp | grep "wineserver" | head -3
echo ""

echo "Terminal log (expert loading):"
TERM_LOG=$(ls -t "${MT5_BASE}/logs/"*.log 2>/dev/null | head -1)
if [ -f "$TERM_LOG" ]; then
    iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | tail -20
fi
echo ""

echo "EA Log:"
EA_LOG=$(ls -t "${MT5_BASE}/MQL5/Logs/"*.log 2>/dev/null | grep -v ".old" | head -1)
if [ -f "$EA_LOG" ]; then
    SIZE=$(stat -c%s "$EA_LOG")
    echo "EA Log: $EA_LOG ($SIZE bytes)"
    iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | grep -i "RiskMgr\|AccountState\|INIT\|MaxPos\|Risk.*mult\|Notify\|HEARTBEAT\|ALL SYSTEMS\|SWITCHED\|loaded" | head -20
else
    echo "NO EA LOG!"
fi
echo ""

echo "Relay:"
pgrep -f "telegram_relay" > /dev/null && echo "Running" || echo "NOT running"
# Restart relay if needed
if ! pgrep -f "telegram_relay" > /dev/null; then
    nohup bash /root/telegram_relay.sh > /var/log/telegram_relay.log 2>&1 &
    sleep 2
    echo "Relay restarted"
fi
echo ""

echo "=== DONE - $(date) ==="
