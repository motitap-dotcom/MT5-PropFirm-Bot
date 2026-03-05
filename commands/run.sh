#!/bin/bash
# =============================================================
# Fix #10: Use existing chart format + add EA section
# =============================================================

echo "=== FIX #10 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
DEFAULT_CHART="$MT5_BASE/MQL5/Profiles/Charts/Default/chart01.chr"
EURO_CHART="$MT5_BASE/MQL5/Profiles/Charts/Euro/chart01.chr"

# ============================================
# STEP 1: Kill MT5
# ============================================
echo "--- STEP 1: Kill MT5 ---"
pkill -9 wineserver 2>/dev/null || true
pkill -9 -f "wine" 2>/dev/null || true
sleep 5

# Delete state
find /root/.wine -name "PropFirmBot_AccountState.dat" -delete 2>/dev/null

echo ""

# ============================================
# STEP 2: Read existing stock chart for format
# ============================================
echo "--- STEP 2: Read Euro chart for format ---"
if [ -f "$EURO_CHART" ]; then
    echo "Euro/chart01.chr:"
    cat "$EURO_CHART"
else
    echo "Euro chart not found!"
fi
echo ""

# ============================================
# STEP 3: Create Default chart from stock + EA
# ============================================
echo "--- STEP 3: Create Default chart with EA ---"

# Copy the Euro chart as base
if [ -f "$EURO_CHART" ]; then
    cp "$EURO_CHART" "$DEFAULT_CHART"
    echo "Copied Euro chart as base"
else
    echo "No Euro chart to copy"
fi

# Now modify it: change symbol to EURUSD and add EA
# Read current content
CURRENT=$(cat "$DEFAULT_CHART" 2>/dev/null)

# Create proper chart with EURUSD and EA
cat > "$DEFAULT_CHART" << 'CHREOF'
<chart>
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
expertmode=33
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
show_data=1
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

echo "Created chart with EA config"
echo "Chart content:"
cat "$DEFAULT_CHART"
echo ""

# Also write the order.wnd file
cat > "$MT5_BASE/MQL5/Profiles/Charts/Default/order.wnd" << 'WNDEOF'
<chart>
id=1
</chart>
WNDEOF
echo ""

# ============================================
# STEP 4: Ensure common.ini is correct
# ============================================
echo "--- STEP 4: common.ini ---"
cat > "$MT5_BASE/config/common.ini" << 'INIEOF'
[Common]
Login=11797849
ProxyEnable=0
CertInstall=0
NewsEnable=0
Server=FundedNext-Server
ProxyType=0
ProxyAddress=
EnableOpenCL=7
ProxyAuth=
Services=4294967295
NewsLanguages=
Source=download.mql5.com
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
[Charts]
ProfileLast=Default
MaxBars=100000
PrintColor=0
SaveDeleted=0
TradeHistory=1
TradeLevels=1
TradeLevelsDrag=0
PreloadCharts=1
INIEOF
echo "common.ini written"
echo ""

# ============================================
# STEP 5: Start MT5 and wait
# ============================================
echo "--- STEP 5: Start MT5 ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

cd "$MT5_BASE"
nohup wine "$MT5_BASE/terminal64.exe" /portable > /tmp/mt5_stdout.log 2>&1 &
echo "MT5 starting... waiting 120 sec"
sleep 120

# ============================================
# STEP 6: Check results
# ============================================
echo "--- STEP 6: Results ---"

echo "Network:"
ss -tnp | grep "wineserver" | head -3
echo ""

echo "Terminal log (last 20 lines):"
TERM_LOG=$(ls -t "${MT5_BASE}/logs/"*.log 2>/dev/null | head -1)
[ -f "$TERM_LOG" ] && iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | tail -20
echo ""

echo "EA Log:"
EA_LOG=$(ls -t "${MT5_BASE}/MQL5/Logs/"*.log 2>/dev/null | grep -v ".old" | head -1)
if [ -f "$EA_LOG" ]; then
    SIZE=$(stat -c%s "$EA_LOG")
    echo "Found: $EA_LOG ($SIZE bytes)"
    iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | head -30
else
    echo "NO EA LOG FILE"
fi
echo ""

echo "Relay:"
pgrep -f "telegram_relay" > /dev/null && echo "Running" || { nohup bash /root/telegram_relay.sh > /var/log/telegram_relay.log 2>&1 &; sleep 2; echo "Restarted"; }
echo ""

echo "=== DONE - $(date) ==="
