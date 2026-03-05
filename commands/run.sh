#!/bin/bash
# Fix git pull + deploy new code + restart
echo "=== FIX DEPLOY $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_SRC="/root/MT5-PropFirm-Bot/EA"
EA_DST="$MT5/MQL5/Experts/PropFirmBot"
CONFIG_SRC="/root/MT5-PropFirm-Bot/configs"
CONFIG_DST="$MT5/MQL5/Files/PropFirmBot"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Stop MT5
echo "=== STOPPING MT5 ==="
pkill -f terminal64 2>/dev/null
sleep 3
pkill -9 -f terminal64 2>/dev/null
sleep 2

# 2. Fix git pull (force reset to remote)
echo "=== FIXING GIT ==="
cd /root/MT5-PropFirm-Bot
git fetch origin claude/bot-server-connection-qmvC0
git reset --hard origin/claude/bot-server-connection-qmvC0
echo "Git HEAD: $(git log --oneline -1)"

# 3. Verify XAUUSD fix in code
echo ""
echo "=== VERIFY CODE FIX ==="
grep -n "XAUUSD\|XAUUSDm\|WARNING.*symbol\|Always try" "$EA_SRC/PropFirmBot.mq5" | head -15

# 4. Copy files
echo ""
echo "=== DEPLOYING ==="
cp "$EA_SRC/"*.mq5 "$EA_DST/"
cp "$EA_SRC/"*.mqh "$EA_DST/"
cp "$CONFIG_SRC/"*.json "$CONFIG_DST/"

# 5. Compile
echo ""
echo "=== COMPILING ==="
cd "$MT5"
wine64 metaeditor64.exe /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log 2>/dev/null
sleep 10
EX5="$EA_DST/PropFirmBot.ex5"
if [ -f "$EX5" ]; then
    SIZE=$(stat -c%s "$EX5")
    echo "OK: PropFirmBot.ex5 = $SIZE bytes"
else
    echo "FAIL: No .ex5 file"
fi

# 6. Ensure chart file exists
echo ""
echo "=== CHART FILE ==="
CHART_DIR="$MT5/MQL5/Profiles/Charts/Default"
ls -la "$CHART_DIR/" 2>/dev/null
# Verify our chart has the EA
grep "PropFirmBot\|XAUUSD" "$CHART_DIR/chart01.chr" 2>/dev/null

# 7. Start MT5
echo ""
echo "=== STARTING MT5 ==="
cd "$MT5"
nohup wine64 terminal64.exe /portable > /dev/null 2>&1 &
echo "Started MT5 (PID: $!)"
echo "Waiting 60 seconds..."
sleep 60

# 8. Check NEW EA logs (filter by timestamp after 10:3)
echo ""
echo "=== EA LOGS (ALL entries) ==="
EALOGDIR="$MT5/MQL5/Logs"
LATEST=$(ls -t "$EALOGDIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    echo "File: $LATEST ($(wc -c < "$LATEST") bytes)"
    # Show ALL log content to see if new entries appeared
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -50
fi

# 9. MT5 main log
echo ""
echo "=== MT5 MAIN LOG ==="
LOGDIR="$MT5/Logs"
LATEST=$(ls -t "$LOGDIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    echo "File: $LATEST ($(wc -c < "$LATEST") bytes)"
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -30
fi

# 10. Check if MT5 process is actually running
echo ""
echo "=== PROCESS CHECK ==="
pgrep -fa terminal64

echo ""
echo "=== DONE $(date) ==="
