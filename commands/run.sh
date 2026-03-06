#!/bin/bash
# Full reset: Kill MT5, create proper chart profile with AutoTrading, restart
export DISPLAY=:99
export WINEPREFIX=/root/.wine

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
PROFILE_DIR="$MT5_BASE/Profiles/Charts/Default"

echo "=== TIME: $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

# Step 1: Kill MT5
echo "=== Step 1: Kill MT5 ==="
pkill -f terminal64.exe 2>/dev/null || true
sleep 5

# Step 2: Find all chart profiles
echo ""
echo "=== Step 2: Find active chart profiles ==="
echo "Profile dirs:"
ls -la "$MT5_BASE/Profiles/Charts/" 2>/dev/null
echo ""
echo "Default profile:"
ls -la "$PROFILE_DIR/" 2>/dev/null

# Step 3: Create proper chart profile with EA and AutoTrading
echo ""
echo "=== Step 3: Create chart profile with AutoTrading ==="
mkdir -p "$PROFILE_DIR"

# Create chart01.chr with EA attached and auto trading enabled
cat > "$PROFILE_DIR/chart01.chr" << 'CHREOF'
<chart>
id=131000000000000001
symbol=EURUSD
period_type=0
period_size=15
digits=5
tick_size=0.000000
position_time=0
scale_fix=0
scale_fix11=0
scale_bar=0
scale_bar_val=0.000000
scale=4
mode=1
fore=0
grid=1
volume=0
scroll=1
shift=1
shift_size=20.000000
fixed_pos=0.000000
ohlc=0
bidline=1
askline=0
lastline=0
days=0
descriptions=0
window_type=3
background_color=0
foreground_color=16777215
barup_color=65280
bardown_color=255
bullcandle_color=65280
bearcandle_color=255
chartline_color=65280
volumes_color=32768
grid_color=10061943
bidline_color=10061943
askline_color=255
lastline_color=49152
stops_color=255
tradeline_color=11186720
tradehistory_color=9498256
<expert>
name=PropFirmBot\PropFirmBot
path=PropFirmBot\PropFirmBot.ex5
expertmode=1
<inputs>
</inputs>
</expert>
<window>
height=100
objects=0
<indicator>
name=Main
path=
apply=1
show=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=0
fixed_height=-1
</indicator>
</window>
</chart>
CHREOF

echo "Chart profile created"
cat "$PROFILE_DIR/chart01.chr" | head -10

# Step 4: Ensure startup.ini is correct
echo ""
echo "=== Step 4: Update startup.ini ==="
cat > "$MT5_BASE/config/startup.ini" << 'INIEOF'
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
[Common]
AutoTrading=1
INIEOF

echo "startup.ini updated"

# Step 5: Also set in common.ini
echo ""
echo "=== Step 5: Update common.ini ==="
# Make sure AutoTrading=1 exists
grep -q "AutoTrading" "$MT5_BASE/config/common.ini" && \
    sed -i 's/AutoTrading=.*/AutoTrading=1/' "$MT5_BASE/config/common.ini" || \
    sed -i '/\[Common\]/a AutoTrading=1' "$MT5_BASE/config/common.ini"

# Step 6: Start MT5 with specific config
echo ""
echo "=== Step 6: Start MT5 ==="
cd "$MT5_BASE"
# Try starting with /config flag pointing to our startup.ini
nohup wine terminal64.exe "/config:$MT5_BASE/config/startup.ini" /autotrading > /dev/null 2>&1 &
sleep 20

echo ""
echo "=== MT5 Process ==="
ps aux | grep terminal64 | grep -v grep

# Step 7: Now send Ctrl+E to the CHART window (not main window)
echo ""
echo "=== Step 7: Send Ctrl+E to enable AutoTrading ==="
sleep 5
# Try sending to all FundedNext windows
for WID in $(xdotool search --name "FundedNext" 2>/dev/null); do
    WNAME=$(xdotool getwindowname "$WID" 2>/dev/null)
    echo "Sending Ctrl+E to window $WID: $WNAME"
    xdotool windowactivate --sync "$WID" 2>/dev/null
    sleep 1
    xdotool key --window "$WID" --clearmodifiers ctrl+e 2>/dev/null
    sleep 1
done

# Also try the EURUSD chart window specifically
CHART_WIN=$(xdotool search --name "EURUSD" 2>/dev/null | head -1)
if [ -n "$CHART_WIN" ]; then
    echo "Found chart window: $CHART_WIN"
    xdotool windowactivate --sync "$CHART_WIN" 2>/dev/null
    sleep 1
    xdotool key --window "$CHART_WIN" --clearmodifiers ctrl+e 2>/dev/null
    echo "Sent Ctrl+E to chart window"
fi

# Step 8: Wait and check
echo ""
echo "=== Step 8: Check EA log ==="
sleep 15

LOG_FILE="$MT5_BASE/MQL5/Logs/$(date -u +%Y%m%d).log"
echo "Last 25 lines:"
tail -25 "$LOG_FILE" 2>/dev/null

echo ""
echo "=== Auto trading errors? ==="
tail -25 "$LOG_FILE" 2>/dev/null | grep -c "auto trading\|10027" 2>/dev/null
echo "(0 = no errors, good!)"

echo ""
echo "DONE $(date)"
