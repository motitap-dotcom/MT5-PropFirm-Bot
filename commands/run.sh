#!/bin/bash
# =============================================================
# Fix #20: Recompile EA with updated code + reload
# EA loaded successfully but shows Risk=70% (old .ex5 from 10:35)
# Need to: deploy new source -> compile -> restart MT5 with /config
# =============================================================

echo "=== FIX #20 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
REPO_DIR="/root/MT5-PropFirm-Bot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine
export WINEDEBUG=-all

# ============================================
# STEP 1: Pull latest code from repo
# ============================================
echo "--- STEP 1: Update repo ---"
cd "$REPO_DIR"
git fetch origin claude/update-server-vnc-wsD2d 2>/dev/null
git checkout claude/update-server-vnc-wsD2d 2>/dev/null
git pull origin claude/update-server-vnc-wsD2d 2>/dev/null
echo "Branch: $(git branch --show-current)"
echo ""

# Verify the fix is in the source
echo "SwitchToFunded risk multiplier in source:"
grep -A10 "SwitchToFunded" "$REPO_DIR/EA/AccountStateManager.mqh" | grep -i "risk_multi\|max_pos\|daily_trades"
echo ""

echo "Default InpMaxPositions:"
grep "InpMaxPositions" "$REPO_DIR/EA/PropFirmBot.mq5"
echo ""

# ============================================
# STEP 2: Deploy EA files
# ============================================
echo "--- STEP 2: Deploy EA files ---"
mkdir -p "$EA_DIR"
cp -v "$REPO_DIR/EA/"*.mq5 "$EA_DIR/"
cp -v "$REPO_DIR/EA/"*.mqh "$EA_DIR/"
echo ""

echo "Deployed files:"
ls -la "$EA_DIR/"
echo ""

# ============================================
# STEP 3: Delete old AccountState.dat EVERYWHERE
# ============================================
echo "--- STEP 3: Clean state files ---"
find /root/.wine -name "PropFirmBot_AccountState.dat" 2>/dev/null -exec rm -v {} \;
find /root/.wine -name "PropFirmBot_AccountState*" 2>/dev/null -exec rm -v {} \;
# Common files dir
COMMON_DIR="/root/.wine/drive_c/users/root/Application Data/MetaQuotes/Terminal/Common/Files"
[ -d "$COMMON_DIR" ] && find "$COMMON_DIR" -name "*AccountState*" -exec rm -v {} \;
# Also in MQL5/Files
find "${MT5_BASE}/MQL5/Files" -name "*AccountState*" 2>/dev/null -exec rm -v {} \;
echo "State files cleaned"
echo ""

# ============================================
# STEP 4: Stop MT5 for compilation
# ============================================
echo "--- STEP 4: Stop MT5 ---"
killall terminal64.exe 2>/dev/null
sleep 3
pkill -9 -f terminal64 2>/dev/null
sleep 2
wineserver -k 2>/dev/null
sleep 3
echo "MT5 stopped"
echo ""

# ============================================
# STEP 5: Compile EA
# ============================================
echo "--- STEP 5: Compile EA ---"
echo "Old .ex5 before compile:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null
echo ""

cd "$MT5_BASE"
wine metaeditor64.exe /compile:"MQL5\\Experts\\PropFirmBot\\PropFirmBot.mq5" /log 2>/dev/null &
COMPILE_PID=$!
echo "MetaEditor PID: $COMPILE_PID"
echo "Waiting 30 seconds for compilation..."
sleep 30
kill $COMPILE_PID 2>/dev/null
wineserver -k 2>/dev/null
sleep 3
sync

echo ""
echo "New .ex5 after compile:"
ls -la "$EA_DIR/PropFirmBot.ex5" 2>/dev/null

# Check compile log
COMPILE_LOG="$EA_DIR/PropFirmBot.log"
if [ -f "$COMPILE_LOG" ]; then
    echo ""
    echo "Compile log:"
    cat "$COMPILE_LOG" 2>/dev/null
fi
echo ""

# Verify .ex5 exists
if [ ! -f "$EA_DIR/PropFirmBot.ex5" ]; then
    echo "ERROR: .ex5 not found after compilation!"
    exit 1
fi
echo "Compilation complete"
echo ""

# ============================================
# STEP 6: Start MT5 with /config
# ============================================
echo "--- STEP 6: Start MT5 ---"
cd "$MT5_BASE"
DISPLAY=:99 nohup wine terminal64.exe "/config:config\\startup.ini" >/dev/null 2>&1 &
echo "Waiting 45 seconds for MT5 to start + EA to load..."
sleep 45

if pgrep -f terminal64 > /dev/null; then
    echo "MT5 is RUNNING"
else
    echo "MT5 FAILED - trying without config..."
    DISPLAY=:99 nohup wine terminal64.exe >/dev/null 2>&1 &
    sleep 30
fi
echo ""

# ============================================
# STEP 7: Verify EA loaded with correct params
# ============================================
echo "--- STEP 7: Verify EA ---"

TERM_LOG=$(ls -t "${MT5_BASE}/logs/"*.log 2>/dev/null | head -1)
echo "Terminal log (expert entries):"
iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | grep -i "expert\|startup\|config\|launch" | tail -10
echo ""

EA_LOG="${MT5_BASE}/MQL5/Logs/20260305.log"
if [ -f "$EA_LOG" ]; then
    echo "EA LOG (last 25 lines):"
    iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | tail -25
else
    echo "NO EA LOG"
fi
echo ""

# Key check: Risk multiplier
echo "--- STEP 8: Parameter check ---"
if [ -f "$EA_LOG" ]; then
    echo "Risk multiplier:"
    iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | grep -i "risk\|multi\|max.*pos\|account.*phase\|funded"
fi
echo ""

# ============================================
# STEP 9: Ensure telegram relay running
# ============================================
echo "--- STEP 9: Telegram relay ---"
if ! pgrep -f telegram_relay > /dev/null; then
    [ -f /root/telegram_relay.sh ] && nohup bash /root/telegram_relay.sh > /root/telegram_relay.log 2>&1 &
    echo "Started"
else
    echo "Running"
fi
echo ""

# Send status to Telegram
echo "--- STEP 10: Telegram status ---"
EA_STATUS="NOT LOADED"
[ -f "$EA_LOG" ] && EA_STATUS="LOADED"
RISK_LINE=$(iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | grep -i "risk.*multi" | tail -1)
curl -s -X POST "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d chat_id="7013213983" \
    -d text="🤖 Fix #20 - Recompiled EA
MT5: $(pgrep -f terminal64 > /dev/null && echo '✅ RUNNING' || echo '❌ DOWN')
EA: ${EA_STATUS}
${RISK_LINE}
Balance: \$1981.41
VNC: $(pgrep -x x11vnc > /dev/null && echo '✅' || echo '❌')" \
    -d parse_mode="HTML" 2>/dev/null | python3 -c "import sys,json; r=json.load(sys.stdin); print('Telegram:', 'OK' if r.get('ok') else r)" 2>/dev/null || echo "Telegram: FAILED"
echo ""

echo "=== DONE - $(date) ==="
