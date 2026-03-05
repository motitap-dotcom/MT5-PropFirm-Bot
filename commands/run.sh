#!/bin/bash
# Try different startup methods to get EA loaded
echo "=== LOAD EA $(date) ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

# 1. Kill all MT5
pkill -9 -f terminal64 2>/dev/null
pkill -9 -f start.exe 2>/dev/null
sleep 3

# 2. Check startup.ini content
echo "=== startup.ini ==="
cat "$MT5/config/startup.ini"

# 3. Try starting MT5 with explicit /config flag
echo ""
echo "=== STARTING WITH /config ==="
cd "$MT5"
nohup wine64 terminal64.exe /config:"$MT5/config/startup.ini" > /tmp/mt5_out.txt 2>&1 &
echo "Started with /config (PID: $!)"
sleep 120

# 4. Check if EA loaded
echo ""
echo "=== EA LOG ==="
EALOG="$MT5/MQL5/Logs/20260305.log"
NEWSIZE=$(stat -c%s "$EALOG" 2>/dev/null)
echo "EA log size: $NEWSIZE bytes (was 102898)"
if [ "$NEWSIZE" -gt 102898 ]; then
    echo "NEW ENTRIES FOUND!"
    iconv -f UTF-16LE -t UTF-8 "$EALOG" 2>/dev/null | tail -30
fi

echo ""
echo "=== MT5 MAIN LOG ==="
MAINLOG="$MT5/logs/20260305.log"
iconv -f UTF-16LE -t UTF-8 "$MAINLOG" 2>/dev/null | tail -15

# 5. If EA didn't load, try different approach
if [ "$NEWSIZE" -le 102898 ]; then
    echo ""
    echo "EA still not loaded. Trying approach 2..."

    # Kill MT5
    pkill -9 -f terminal64 2>/dev/null
    sleep 3

    # Approach 2: Create a proper .set file and use /config
    SET_FILE="$MT5/MQL5/Presets/PropFirmBot.set"
    mkdir -p "$(dirname "$SET_FILE")"
    cat > "$SET_FILE" << 'SETEOF'
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
InpAccountPhase=2
InpAccountSize=2000
InpMaxDailyDD=0
InpMaxTotalDD=6.0
InpTelegramToken=8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g
InpTelegramChatID=7013213983
InpOBLookback=30
InpFVGMinPoints=30.0
SETEOF

    echo "Created preset file: $SET_FILE"

    # Update startup.ini to reference the preset
    cat > "$MT5/config/startup.ini" << 'INIEOF'
[Common]
Login=11797849
Password=gazDE62##
Server=FundedNext-Server
ProxyEnable=0
CertInstall=0
NewsEnable=0
EnableOpenCL=7
Services=4294967295
Source=download.mql5.com
[StartUp]
Expert=PropFirmBot\PropFirmBot
ExpertParameters=MQL5\Presets\PropFirmBot.set
Symbol=EURUSD
Period=M15
[Experts]
AllowLiveTrading=1
AllowDllImport=0
Enabled=1
Account=1
Profile=0
Chart=0
WebRequest=1
WebRequestUrl=https://api.telegram.org
[Charts]
ProfileLast=Default
MaxBars=100000
TradeHistory=1
TradeLevels=1
PreloadCharts=1
INIEOF

    echo "Updated startup.ini"
    cat "$MT5/config/startup.ini"

    # Restart MT5 with new config
    echo ""
    echo "=== RESTARTING WITH UPDATED CONFIG ==="
    cd "$MT5"
    nohup wine64 terminal64.exe /config:"$MT5/config/startup.ini" > /tmp/mt5_out2.txt 2>&1 &
    echo "Started (PID: $!)"
    sleep 120

    echo ""
    echo "=== EA LOG (attempt 2) ==="
    NEWSIZE=$(stat -c%s "$EALOG" 2>/dev/null)
    echo "EA log size: $NEWSIZE bytes"
    if [ "$NEWSIZE" -gt 102898 ]; then
        echo "NEW ENTRIES FOUND!"
    fi
    iconv -f UTF-16LE -t UTF-8 "$EALOG" 2>/dev/null | tail -20

    echo ""
    echo "=== MT5 MAIN LOG (attempt 2) ==="
    iconv -f UTF-16LE -t UTF-8 "$MAINLOG" 2>/dev/null | tail -15
fi

echo ""
echo "=== DONE $(date) ==="
