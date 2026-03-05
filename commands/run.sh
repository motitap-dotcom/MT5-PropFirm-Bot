#!/bin/bash
# Fix chart file encoding (UTF-16LE) + restart MT5
echo "=== FIX ENCODING $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Stop MT5
echo "=== STOPPING MT5 ==="
pkill -f terminal64 2>/dev/null
sleep 3
pkill -9 -f terminal64 2>/dev/null
sleep 2

# 2. Create proper UTF-16LE chart file using Python
echo "=== CREATING PROPER CHART FILE ==="
CHART_DIR="$MT5/MQL5/Profiles/Charts/Default"

python3 << 'PYEOF'
import codecs

# Read the Euro template (it's UTF-16LE with BOM)
template_path = "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Profiles/Charts/Euro/chart01.chr"

try:
    with open(template_path, 'rb') as f:
        raw = f.read()
    # Detect BOM
    if raw[:2] == b'\xff\xfe':
        content = raw[2:].decode('utf-16-le')
    else:
        content = raw.decode('utf-16-le')
    print(f"Read template: {len(content)} chars")
except Exception as e:
    print(f"Error reading template: {e}")
    # Fallback: create from scratch
    content = ""

# Build EA section
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

if content:
    # Modify the template
    import re
    # Remove existing expert section if any
    content = re.sub(r'<expert>.*?</expert>\r?\n?', '', content, flags=re.DOTALL)
    # Change symbol to EURUSD
    content = re.sub(r'^symbol=.*$', 'symbol=EURUSD', content, flags=re.MULTILINE)
    # Change period to M15
    content = re.sub(r'^period_type=.*$', 'period_type=0', content, flags=re.MULTILINE)
    content = re.sub(r'^period_size=.*$', 'period_size=15', content, flags=re.MULTILINE)
    # Insert EA before first <window>
    content = content.replace('<window>', ea_section + '<window>', 1)
else:
    # Create minimal chart from scratch
    content = """<chart>
id=0
symbol=EURUSD
period_type=0
period_size=15
digits=5
tick_size=0.000000
position_time=0
scale_fix=0
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
window_type=1
background_color=0
foreground_color=16777215
barup_color=65280
bardown_color=65280
bullcandle_color=0
bearcandle_color=16777215
chartline_color=65280
volumes_color=3329330
grid_color=10061943
bidline_color=10061943
askline_color=255
lastline_color=49152
stops_color=255
""" + ea_section + """<window>
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
expertmode=0
fixed_height=-1

</indicator>
</window>
</chart>
"""

# Write as UTF-16LE with BOM
output_path = "/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Profiles/Charts/Default/chart01.chr"
with open(output_path, 'wb') as f:
    f.write(b'\xff\xfe')  # UTF-16LE BOM
    f.write(content.encode('utf-16-le'))

print(f"Written chart file: {len(content)} chars")
# Verify
with open(output_path, 'rb') as f:
    data = f.read()
print(f"File size: {len(data)} bytes")
# Check if PropFirmBot is in the file
if b'P\x00r\x00o\x00p\x00F\x00i\x00r\x00m\x00' in data:
    print("PropFirmBot found in chart file!")
else:
    print("WARNING: PropFirmBot NOT found in chart file!")
PYEOF

echo ""
echo "=== CHART FILE CHECK ==="
ls -la "$CHART_DIR/chart01.chr"
# Verify by reading back as UTF-16
python3 -c "
f=open('/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Profiles/Charts/Default/chart01.chr','rb')
data=f.read()
text=data[2:].decode('utf-16-le')
for line in text.split('\n'):
    line=line.strip()
    if 'PropFirmBot' in line or 'XAUUSD' in line or 'symbol=' in line or 'period_size=' in line:
        print(line)
f.close()
"

# 3. Start MT5
echo ""
echo "=== STARTING MT5 ==="
cd "$MT5"
nohup wine64 terminal64.exe /portable > /dev/null 2>&1 &
echo "Started (PID: $!)"
echo "Waiting 90 seconds..."
sleep 90

# 4. Check EA logs for NEW entries
echo ""
echo "=== EA LOG ==="
EALOGDIR="$MT5/MQL5/Logs"
LATEST=$(ls -t "$EALOGDIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    SIZE=$(stat -c%s "$LATEST" 2>/dev/null)
    echo "File: $LATEST ($SIZE bytes)"
    # Show last 40 lines - look for new timestamps
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -40
fi

echo ""
echo "=== DONE $(date) ==="
