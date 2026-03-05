#!/bin/bash
# =============================================================
# Fix #18: Create chart01.chr in Default profile with EA config
# Problem: Default/ dir is empty -> MT5 opens chart but no EA
# Solution: Create proper chart profile with EA attached
# =============================================================

echo "=== FIX #18 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
PROFILE_DIR="${MT5_BASE}/MQL5/Profiles/Charts/Default"
export DISPLAY=:99
export WINEPREFIX=/root/.wine
export WINEDEBUG=-all

# ============================================
# STEP 1: Stop MT5 gracefully (NOT wineserver)
# ============================================
echo "--- STEP 1: Stop MT5 ---"
killall terminal64.exe 2>/dev/null
sleep 3
# If still running, force kill
if pgrep -f terminal64 > /dev/null; then
    pkill -9 -f terminal64 2>/dev/null
    sleep 2
fi
echo "MT5 stopped: $(pgrep -f terminal64 > /dev/null && echo 'STILL RUNNING' || echo 'OK')"
echo ""

# ============================================
# STEP 2: Create chart01.chr with EA in Default profile
# ============================================
echo "--- STEP 2: Create chart01.chr ---"
mkdir -p "$PROFILE_DIR"

# Create chart profile content (plain text first, then convert to UTF-16LE)
cat > /tmp/chart01.txt << 'CHART_EOF'
<chart>
id=130000000000000001
symbol=EURUSD
period_type=0
period_size=15
digits=5
tick_size=0.000000
position_time=0
scale_fix=0
scale_fixed_min=0.000000
scale_fixed_max=0.000000
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
window_type=0
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

<expert>
name=PropFirmBot\PropFirmBot
path=Experts\PropFirmBot\PropFirmBot.ex5
flags=343
window_num=0
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
CHART_EOF

# Convert to UTF-16LE with BOM and CRLF line endings
# First convert line endings to CRLF
sed 's/$/\r/' /tmp/chart01.txt > /tmp/chart01_crlf.txt

# Add BOM (FF FE) and convert to UTF-16LE
python3 -c "
with open('/tmp/chart01_crlf.txt', 'r') as f:
    content = f.read()
# Write UTF-16LE with BOM
with open('${PROFILE_DIR}/chart01.chr', 'wb') as f:
    f.write(b'\xff\xfe')  # UTF-16LE BOM
    f.write(content.encode('utf-16-le'))
print('chart01.chr created successfully')
print(f'Size: {len(content)} chars')
"

echo "Verify chart01.chr:"
file "${PROFILE_DIR}/chart01.chr" 2>/dev/null
ls -la "${PROFILE_DIR}/chart01.chr" 2>/dev/null
echo ""

# Also verify the expert section is in the file
echo "Expert section check:"
iconv -f UTF-16LE -t UTF-8 "${PROFILE_DIR}/chart01.chr" 2>/dev/null | grep -A5 "expert"
echo ""

# ============================================
# STEP 3: Verify common.ini has correct StartUp
# ============================================
echo "--- STEP 3: Verify common.ini ---"
grep -A5 "StartUp" "${MT5_BASE}/config/common.ini" 2>/dev/null
echo ""

# ============================================
# STEP 4: Verify .ex5 exists
# ============================================
echo "--- STEP 4: Verify .ex5 ---"
ls -la "${MT5_BASE}/MQL5/Experts/PropFirmBot/PropFirmBot.ex5" 2>/dev/null
echo ""

# ============================================
# STEP 5: Ensure VNC is running
# ============================================
echo "--- STEP 5: VNC check ---"
if ! pgrep -x Xvfb > /dev/null; then
    rm -f /tmp/.X99-lock /tmp/.X11-unix/X99 2>/dev/null
    Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX +render -noreset &
    sleep 3
fi
if ! pgrep -x x11vnc > /dev/null; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw -xkb 2>/dev/null
    sleep 2
fi
echo "Xvfb: $(pgrep -x Xvfb || echo 'NOT running')"
echo "x11vnc: $(pgrep -x x11vnc || echo 'NOT running')"
echo ""

# ============================================
# STEP 6: Delete old AccountState.dat (has wrong multiplier values)
# ============================================
echo "--- STEP 6: Clean old state file ---"
find "${MT5_BASE}" -name "PropFirmBot_AccountState.dat" -delete 2>/dev/null
find /root/.wine -path "*/MQL5/Files/Common/*AccountState*" -delete 2>/dev/null
echo "Old state files deleted"
echo ""

# ============================================
# STEP 7: Start MT5
# ============================================
echo "--- STEP 7: Start MT5 ---"
cd "$MT5_BASE"
DISPLAY=:99 nohup wine terminal64.exe >/dev/null 2>&1 &
echo "Waiting 25 seconds for MT5 to start and load EA..."
sleep 25

if pgrep -f terminal64 > /dev/null; then
    echo "MT5 is RUNNING"
else
    echo "MT5 FAILED to start!"
    exit 1
fi
echo ""

# ============================================
# STEP 8: Check if EA loaded
# ============================================
echo "--- STEP 8: Check EA status ---"

# Check terminal log for expert loading
TERM_LOG=$(ls -t "${MT5_BASE}/logs/"*.log 2>/dev/null | head -1)
echo "Terminal log (last 15 lines):"
iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | tail -15
echo ""

echo "Expert-related log entries:"
iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | grep -i "expert\|PropFirm\|loaded\|error\|warning" | tail -10
echo ""

# Check EA log
EA_LOG="${MT5_BASE}/MQL5/Logs/20260305.log"
if [ -f "$EA_LOG" ]; then
    echo "EA LOG EXISTS! Size: $(stat -c%s "$EA_LOG") bytes"
    echo "EA log content:"
    iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | tail -20
else
    echo "No EA log file - EA may not have loaded"
fi
echo ""

# ============================================
# STEP 9: Check telegram relay
# ============================================
echo "--- STEP 9: Telegram relay ---"
if pgrep -f telegram_relay > /dev/null; then
    echo "Telegram relay RUNNING"
else
    echo "Starting telegram relay..."
    if [ -f /root/telegram_relay.sh ]; then
        nohup bash /root/telegram_relay.sh > /root/telegram_relay.log 2>&1 &
        echo "Started"
    else
        echo "telegram_relay.sh NOT found - creating it..."
        cat > /root/telegram_relay.sh << 'RELAY_EOF'
#!/bin/bash
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
QUEUE_FILE="/root/.wine/drive_c/Program Files/MetaTrader 5/MQL5/Files/PropFirmBot/telegram_queue.txt"
CHECK_INTERVAL=5
send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" -d text="${1}" -d parse_mode="HTML" > /dev/null 2>&1
}
echo "[TelegramRelay] Started at $(date)"
send_telegram "🤖 PropFirmBot Telegram Relay started!"
LAST_POS=0
[ -f "$QUEUE_FILE" ] && LAST_POS=$(wc -c < "$QUEUE_FILE")
while true; do
    if [ -f "$QUEUE_FILE" ]; then
        CURRENT_SIZE=$(wc -c < "$QUEUE_FILE")
        if [ "$CURRENT_SIZE" -gt "$LAST_POS" ]; then
            NEW_LINES=$(tail -c +$((LAST_POS + 1)) "$QUEUE_FILE")
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                MESSAGE=$(echo "$line" | sed 's/^[^|]*|//')
                [ -n "$MESSAGE" ] && send_telegram "$MESSAGE" && sleep 1
            done <<< "$NEW_LINES"
            LAST_POS=$CURRENT_SIZE
        fi
    fi
    sleep $CHECK_INTERVAL
done
RELAY_EOF
        nohup bash /root/telegram_relay.sh > /root/telegram_relay.log 2>&1 &
        echo "Created and started"
    fi
fi
echo ""

# ============================================
# STEP 10: Send test telegram
# ============================================
echo "--- STEP 10: Test Telegram ---"
curl -s -X POST "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d chat_id="7013213983" \
    -d text="🤖 Fix #18 Status Report:
MT5: $(pgrep -f terminal64 > /dev/null && echo 'RUNNING' || echo 'DOWN')
EA: $([ -f '${EA_LOG}' ] && echo 'LOG EXISTS' || echo 'NOT LOADED')
VNC: $(pgrep -x x11vnc > /dev/null && echo 'RUNNING' || echo 'DOWN')
Relay: $(pgrep -f telegram_relay > /dev/null && echo 'RUNNING' || echo 'DOWN')" \
    -d parse_mode="HTML" 2>/dev/null | python3 -c "import sys,json; r=json.load(sys.stdin); print('Telegram:', 'OK' if r.get('ok') else r)" 2>/dev/null || echo "Telegram: FAILED"
echo ""

echo "=== DONE - $(date) ==="
