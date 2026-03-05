#!/bin/bash
# =============================================================
# Fix #12: Restore original common.ini format + Environment key
# =============================================================

echo "=== FIX #12 - $(date) ==="

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
# STEP 2: Restore common.ini with ALL original fields
# ============================================
echo "--- STEP 2: Restore common.ini ---"

# Use the EXACT format from the working config we captured earlier
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

echo "Restored with Environment key"
echo ""

# ============================================
# STEP 3: Also check what the WORKING chart01.chr looked like
# ============================================
echo "--- STEP 3: Check chart that MT5 saved when EA was working ---"
# MT5 saves charts when it exits properly. The chart dir modified at 10:33-10:45
# was when it was working. Check what MT5 itself wrote to Default:
echo "Default chart01.chr size/encoding:"
ls -la "$MT5_BASE/MQL5/Profiles/Charts/Default/chart01.chr" 2>/dev/null
file "$MT5_BASE/MQL5/Profiles/Charts/Default/chart01.chr" 2>/dev/null
echo ""

echo "Content (UTF-16 to UTF-8):"
iconv -f UTF-16LE -t UTF-8 "$MT5_BASE/MQL5/Profiles/Charts/Default/chart01.chr" 2>/dev/null | head -60
echo ""

# ============================================
# STEP 4: Start MT5 and wait VERY LONG (3 min)
# ============================================
echo "--- STEP 4: Start MT5 ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

cd "$MT5_BASE"
nohup wine "$MT5_BASE/terminal64.exe" /portable > /tmp/mt5_stdout.log 2>&1 &
echo "MT5 starting... waiting 180 sec (3 minutes)"
sleep 180

# ============================================
# STEP 5: Full results
# ============================================
echo "--- STEP 5: Results ---"

echo "Terminal log (all expert references):"
TERM_LOG=$(ls -t "${MT5_BASE}/logs/"*.log 2>/dev/null | head -1)
[ -f "$TERM_LOG" ] && iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | grep -i "expert\|error\|fail\|loaded" | tail -10
echo ""

echo "Terminal log (last 10 lines):"
[ -f "$TERM_LOG" ] && iconv -f UTF-16LE -t UTF-8 "$TERM_LOG" 2>/dev/null | tail -10
echo ""

echo "EA Log:"
EA_LOG="${MT5_BASE}/MQL5/Logs/20260305.log"
if [ -f "$EA_LOG" ]; then
    SIZE=$(stat -c%s "$EA_LOG")
    echo "FOUND: ($SIZE bytes)"
    iconv -f UTF-16LE -t UTF-8 "$EA_LOG" 2>/dev/null | head -30
else
    echo "NO EA LOG TODAY"
    ls -la "${MT5_BASE}/MQL5/Logs/" 2>/dev/null | tail -5
fi
echo ""

# Restart relay
pgrep -f "telegram_relay" > /dev/null || nohup bash /root/telegram_relay.sh > /var/log/telegram_relay.log 2>&1 &
echo "Relay: running=$(pgrep -c -f telegram_relay 2>/dev/null || echo 0)"
echo ""

echo "=== DONE - $(date) ==="
