#!/bin/bash
# =============================================================
# Fix #11: Write chart profile in UTF-16LE encoding!
# =============================================================

echo "=== FIX #11 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
DEFAULT_CHART="$MT5_BASE/MQL5/Profiles/Charts/Default/chart01.chr"

# ============================================
# STEP 1: Kill MT5
# ============================================
echo "--- STEP 1: Kill MT5 ---"
pkill -9 wineserver 2>/dev/null || true
pkill -9 -f "wine" 2>/dev/null || true
sleep 5

# Delete state
find /root/.wine -name "PropFirmBot_AccountState.dat" -delete 2>/dev/null
echo "Done"
echo ""

# ============================================
# STEP 2: Write chart in UTF-16LE
# ============================================
echo "--- STEP 2: Write UTF-16LE chart ---"

# Write ASCII first, then convert
cat > /tmp/chart_ascii.chr << 'CHREOF'
<chart>
id=1
symbol=EURUSD
period_type=0
period_size=15
digits=5
tick_size=0.000000
position_time=0
scale_fix=0
scale_fixed_min=1.000000
scale_fixed_max=2.000000
scale_fix11=0
scale_bar=0
scale_bar_val=0.000000
scale=4
mode=1
fore=0
grid=0
volume=0
scroll=1
shift=1
shift_size=20.000000
fixed_pos=0.000000
ohlc=1
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
volumes_color=3329330
grid_color=10061943
bidline_color=10061943
askline_color=255
lastline_color=49152
stops_color=255

<expert>
name=PropFirmBot\PropFirmBot
path=PropFirmBot\PropFirmBot.ex5
expertmode=33
<inputs>
</inputs>
</expert>

<window>
height=100

<indicator>
name=Main
path=
apply=1
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
</indicator>
</window>

</chart>
CHREOF

# Convert to UTF-16LE with BOM
iconv -f UTF-8 -t UTF-16LE /tmp/chart_ascii.chr > "$DEFAULT_CHART"

# Add UTF-16LE BOM at the beginning
python3 -c "
import sys
with open('$DEFAULT_CHART', 'rb') as f:
    data = f.read()
# Add BOM if not present
if not data.startswith(b'\xff\xfe'):
    with open('$DEFAULT_CHART', 'wb') as f:
        f.write(b'\xff\xfe' + data)
    print('BOM added')
else:
    print('BOM already present')
"

echo "Chart file info:"
ls -la "$DEFAULT_CHART"
file "$DEFAULT_CHART"
echo ""

# Also write order.wnd in UTF-16LE
printf '<chart>\r\nid=1\r\n</chart>\r\n' | iconv -f UTF-8 -t UTF-16LE > "$MT5_BASE/MQL5/Profiles/Charts/Default/order.wnd"
python3 -c "
with open('$MT5_BASE/MQL5/Profiles/Charts/Default/order.wnd', 'rb') as f:
    data = f.read()
if not data.startswith(b'\xff\xfe'):
    with open('$MT5_BASE/MQL5/Profiles/Charts/Default/order.wnd', 'wb') as f:
        f.write(b'\xff\xfe' + data)
"

# ============================================
# STEP 3: Verify chart content
# ============================================
echo "--- STEP 3: Verify chart ---"
echo "First 20 lines (converted back):"
iconv -f UTF-16LE -t UTF-8 "$DEFAULT_CHART" 2>/dev/null | head -20
echo "..."
echo "Expert section:"
iconv -f UTF-16LE -t UTF-8 "$DEFAULT_CHART" 2>/dev/null | grep -A5 "expert"
echo ""

# ============================================
# STEP 4: Start MT5
# ============================================
echo "--- STEP 4: Start MT5 ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

cd "$MT5_BASE"
nohup wine "$MT5_BASE/terminal64.exe" /portable > /tmp/mt5_stdout.log 2>&1 &
echo "MT5 starting... waiting 90 sec"
sleep 90

# ============================================
# STEP 5: Results
# ============================================
echo "--- STEP 5: Results ---"

echo "Network:"
ss -tnp | grep "wineserver" | head -3
echo ""

echo "Terminal log (last entries):"
TERM_LOG=$(ls -t "${MT5_BASE}/logs/"*.log 2>/dev/null | head -1)
[ -f "$TERM_LOG" ] && iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | grep -i "expert\|started\|synchronized\|error\|failed" | tail -10
echo ""

echo "EA Log:"
EA_LOG="${MT5_BASE}/MQL5/Logs/20260305.log"
if [ -f "$EA_LOG" ]; then
    SIZE=$(stat -c%s "$EA_LOG")
    echo "FOUND: $EA_LOG ($SIZE bytes)"
    iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | head -30
else
    echo "NO log for today. Available:"
    ls -la "${MT5_BASE}/MQL5/Logs/" | grep -v ".old"
fi
echo ""

# Restart relay if needed
pgrep -f "telegram_relay" > /dev/null || { nohup bash /root/telegram_relay.sh > /var/log/telegram_relay.log 2>&1 & }
echo "Relay: $(pgrep -c -f telegram_relay 2>/dev/null) processes"
echo ""

echo "=== DONE - $(date) ==="
