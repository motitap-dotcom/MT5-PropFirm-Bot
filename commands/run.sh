#!/bin/bash
# =============================================================
# Fix #13: DELETE Default profile so MT5 uses [StartUp] to load EA
# =============================================================

echo "=== FIX #13 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"

# ============================================
# STEP 1: Kill MT5
# ============================================
echo "--- STEP 1: Kill MT5 ---"
pkill -9 wineserver 2>/dev/null || true
pkill -9 -f "wine" 2>/dev/null || true
sleep 5

find /root/.wine -name "PropFirmBot_AccountState.dat" -delete 2>/dev/null
echo "Done"
echo ""

# ============================================
# STEP 2: DELETE Default chart profile
# ============================================
echo "--- STEP 2: Delete Default profile ---"
rm -rf "$MT5_BASE/MQL5/Profiles/Charts/Default/"
rm -rf "$MT5_BASE/profiles/default/"
rm -rf "$MT5_BASE/Profiles/Charts/Default/"
rm -rf "$MT5_BASE/config/charts/"

echo "All Default profiles deleted"
echo "Remaining chart profiles:"
find "$MT5_BASE" -name "*.chr" 2>/dev/null | head -10
echo ""

# ============================================
# STEP 3: Ensure common.ini has StartUp
# ============================================
echo "--- STEP 3: common.ini ---"
cat > "$MT5_BASE/config/common.ini" << 'INIEOF'
[Common]
Login=11797849
ProxyEnable=0
CertInstall=0
NewsEnable=0
Environment=F008C7293503CED0045B07842FC57A638AA2FD5F10DEE8EA7AD19815A339B9A21E36157778467577E33A229F2FC5240D
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
ObsoleteLasttime=1772635517
PreloadCharts=1
INIEOF
echo "Written"
echo ""

# ============================================
# STEP 4: Start MT5
# ============================================
echo "--- STEP 4: Start MT5 ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

cd "$MT5_BASE"
nohup wine "$MT5_BASE/terminal64.exe" /portable > /tmp/mt5_stdout.log 2>&1 &
echo "MT5 starting... waiting 120 sec"
sleep 120

# ============================================
# STEP 5: Results
# ============================================
echo "--- STEP 5: Results ---"

echo "Terminal log (expert refs + last entries):"
TERM_LOG=$(ls -t "${MT5_BASE}/logs/"*.log 2>/dev/null | head -1)
if [ -f "$TERM_LOG" ]; then
    iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | tail -15
fi
echo ""

echo "EA Log:"
EA_LOG="${MT5_BASE}/MQL5/Logs/20260305.log"
if [ -f "$EA_LOG" ]; then
    SIZE=$(stat -c%s "$EA_LOG")
    echo "FOUND: ($SIZE bytes)"
    iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | grep -i "RiskMgr\|AccountState\|Risk.*mult\|MaxPos\|INIT.*ALL\|HEARTBEAT\|SWITCHED\|Notify\|loaded" | head -20
else
    echo "NO EA LOG - checking all:"
    ls -la "${MT5_BASE}/MQL5/Logs/" 2>/dev/null | tail -5
fi
echo ""

# Check if Default profile was recreated by MT5
echo "Default profile (recreated by MT5?):"
ls -la "$MT5_BASE/MQL5/Profiles/Charts/Default/" 2>/dev/null || echo "Not recreated"
echo ""

pgrep -f "telegram_relay" > /dev/null || nohup bash /root/telegram_relay.sh > /var/log/telegram_relay.log 2>&1 &
echo "Relay: $(pgrep -c -f telegram_relay 2>/dev/null || echo 0)"

echo "=== DONE - $(date) ==="
