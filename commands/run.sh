#!/bin/bash
# Deploy updated EA code + create fresh chart + restart MT5
echo "=== DEPLOY + RESTART $(date) ==="

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

# 2. Pull latest code
echo "=== PULLING LATEST CODE ==="
cd /root/MT5-PropFirm-Bot
git pull origin claude/bot-server-connection-qmvC0 2>&1 | tail -5

# 3. Copy EA files
echo ""
echo "=== DEPLOYING EA FILES ==="
cp -v "$EA_SRC/"*.mq5 "$EA_DST/" 2>/dev/null
cp -v "$EA_SRC/"*.mqh "$EA_DST/" 2>/dev/null

# 4. Copy config files
echo ""
echo "=== DEPLOYING CONFIGS ==="
mkdir -p "$CONFIG_DST"
cp -v "$CONFIG_SRC/"*.json "$CONFIG_DST/" 2>/dev/null

# 5. Compile EA
echo ""
echo "=== COMPILING EA ==="
cd "$MT5"
wine64 metaeditor64.exe /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log 2>/dev/null
sleep 10

# Check compile result
EX5="$EA_DST/PropFirmBot.ex5"
if [ -f "$EX5" ]; then
    echo "Compiled: $(ls -la "$EX5")"
else
    echo "ERROR: Compilation failed!"
    # Check compile log
    cat "$EA_DST/PropFirmBot.log" 2>/dev/null | tail -20
fi

# 6. Create a fresh chart file with EA attached
echo ""
echo "=== CREATING FRESH CHART ==="
CHART_DIR="$MT5/MQL5/Profiles/Charts/Default"
mkdir -p "$CHART_DIR"

# Create chart01.chr with PropFirmBot EA and EURUSD M15
cat > "$CHART_DIR/chart01.chr" << 'CHARTEOF'
<chart>
id=0
symbol=EURUSD
period_type=0
period_size=15
digits=5
<expert>
name=PropFirmBot\PropFirmBot
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
</chart>
CHARTEOF

echo "Created chart01.chr"

# Create order.wnd
cat > "$CHART_DIR/order.wnd" << 'ORDEREOF'
<window>
<maximized>0
<rect>
0
0
1280
1024
</rect>
</window>
ORDEREOF

echo "Created order.wnd"
ls -la "$CHART_DIR/"

# 7. Start MT5
echo ""
echo "=== STARTING MT5 ==="
cd "$MT5"
nohup wine64 terminal64.exe /portable > /dev/null 2>&1 &
echo "MT5 started (PID: $!)"

# Wait longer for EA to initialize
echo "Waiting 45 seconds for MT5 + EA to load..."
sleep 45

# 8. Check EA logs
echo ""
echo "=== EA LOG (new session) ==="
EALOGDIR="$MT5/MQL5/Logs"
LATEST=$(ls -t "$EALOGDIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    echo "Log: $LATEST"
    # Only show entries from AFTER our restart (10:3x timestamps)
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | grep -E "INIT|Symbol|RiskMgr|NewsFilter|Signal|Scanning|XAUUSD|XAUUSDm|WARNING|Symbols" | tail -30
fi

# 9. Check MT5 main log
echo ""
echo "=== MT5 LOG ==="
LOGDIR="$MT5/Logs"
LATEST=$(ls -t "$LOGDIR/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
    iconv -f UTF-16LE -t UTF-8 "$LATEST" 2>/dev/null | tail -20
fi

echo ""
echo "=== DONE $(date) ==="
