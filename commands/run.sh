#!/bin/bash
# Create proper chart from existing template + add EA
echo "=== FIX CHART $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Stop MT5
echo "=== STOPPING MT5 ==="
pkill -f terminal64 2>/dev/null
sleep 3
pkill -9 -f terminal64 2>/dev/null
sleep 2

# 2. Show a real chart file from another profile for reference
echo "=== SAMPLE CHART FILE (Euro/chart01.chr) ==="
cat "$MT5/MQL5/Profiles/Charts/Euro/chart01.chr" 2>/dev/null | head -60

# 3. Copy Euro chart01 as our template
echo ""
echo "=== COPYING TEMPLATE CHART ==="
CHART_DIR="$MT5/MQL5/Profiles/Charts/Default"
cp "$MT5/MQL5/Profiles/Charts/Euro/chart01.chr" "$CHART_DIR/chart01.chr"

# 4. Change symbol to EURUSD (if needed) and add EA section
# First check what symbol the Euro chart uses
echo "Symbol in template:"
grep "^symbol=" "$CHART_DIR/chart01.chr" | head -1

# 5. Now inject the EA expert section into the chart
# The EA expert section needs to go inside the <chart> block
# Find a good insertion point - after the main chart properties, before <window>
python3 << 'PYEOF'
import sys

chart_path = "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Profiles/Charts/Default/chart01.chr"

with open(chart_path, 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# EA section to inject
ea_section = """<expert>
name=PropFirmBot\\PropFirmBot
path=PropFirmBot\\PropFirmBot.ex5
flags=343
window_num=0
<inputs>
InpTradeEURUSD=true
InpTradeGBPUSD=true
InpTradeUSDJPY=true
InpTradeXAUUSD=true
InpRiskPercent=0.5
InpMaxRiskPercent=0.75
InpMinRiskPercent=0.25
InpMaxPositions=3
InpMaxDailyTrades=8
InpMaxConsecutiveLosses=5
InpMinRR=1.5
InpMaxSpreadMajor=3.5
InpMaxSpreadXAU=7.0
InpNewsBefore=15
InpNewsAfter=15
InpTrailingActivation=15.0
InpTrailingDistance=10.0
InpBEActivation=10.0
InpBEOffset=2.0
InpAccountPhase=PHASE_FUNDED
InpAccountSize=2000
InpMaxDailyDD=0
InpMaxTotalDD=6.0
InpTelegramToken=8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g
InpTelegramChatID=7013213983
InpOBLookback=30
InpFVGMinPoints=30.0
</inputs>
</expert>
"""

# Remove any existing expert section
import re
content = re.sub(r'<expert>.*?</expert>\n?', '', content, flags=re.DOTALL)

# Change symbol to EURUSD and period to M15
content = re.sub(r'^symbol=.*$', 'symbol=EURUSD', content, flags=re.MULTILINE)
content = re.sub(r'^period_type=.*$', 'period_type=0', content, flags=re.MULTILINE)
content = re.sub(r'^period_size=.*$', 'period_size=15', content, flags=re.MULTILINE)

# Insert EA section before first <window> tag
if '<window>' in content:
    content = content.replace('<window>', ea_section + '<window>', 1)
else:
    # If no window tag, append before </chart>
    content = content.replace('</chart>', ea_section + '</chart>')

with open(chart_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Chart file updated successfully")
print(f"File size: {len(content)} bytes")
PYEOF

echo ""
echo "=== VERIFY CHART ==="
grep -n "expert\|PropFirmBot\|EURUSD\|symbol=\|period\|XAUUSD\|window" "$CHART_DIR/chart01.chr" 2>/dev/null | head -20

# 6. Also create order.wnd if missing
if [ ! -f "$CHART_DIR/order.wnd" ]; then
    cat > "$CHART_DIR/order.wnd" << 'EOF'
<window>
<maximized>1
<rect>
0
0
1280
1024
</rect>
</window>
EOF
fi

# 7. Start MT5
echo ""
echo "=== STARTING MT5 ==="
cd "$MT5"
nohup wine64 terminal64.exe /portable > /dev/null 2>&1 &
echo "Started (PID: $!)"
echo "Waiting 90 seconds..."
sleep 90

# 8. Check logs
echo ""
echo "=== EA LOG (last entries) ==="
EALOGDIR="$MT5/MQL5/Logs"
LATEST=$(ls -t "$EALOGDIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    SIZE=$(stat -c%s "$LATEST" 2>/dev/null)
    echo "File: $LATEST ($SIZE bytes)"
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -30
fi

echo ""
echo "=== MT5 MAIN LOG ==="
LOGDIR="$MT5/Logs"
ls -la "$LOGDIR/" 2>/dev/null | tail -5
LATEST=$(ls -t "$LOGDIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -20
fi

echo ""
echo "=== DONE $(date) ==="
