#!/bin/bash
# =============================================================
# Fix #7: Fix common.ini + proper EA auto-load + restart
# =============================================================

echo "=== FIX #7 - $(date) ==="

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="${MT5_BASE}/MQL5/Experts/PropFirmBot"
FILES_DIR="${MT5_BASE}/MQL5/Files/PropFirmBot"
CONFIG_DIR="${MT5_BASE}/config"

# ============================================
# STEP 1: Kill MT5
# ============================================
echo "--- STEP 1: Kill MT5 ---"
pkill -9 wineserver 2>/dev/null || true
pkill -9 -f "wine\|start.exe" 2>/dev/null || true
sleep 5
echo "Killed"
echo ""

# ============================================
# STEP 2: Show and fix common.ini
# ============================================
echo "--- STEP 2: Fix common.ini ---"
echo "Current common.ini:"
cat "$CONFIG_DIR/common.ini"
echo ""
echo "---"

# Write a clean common.ini
cat > "$CONFIG_DIR/common.ini" << 'INIEOF'
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

echo "Written clean common.ini"
cat "$CONFIG_DIR/common.ini"
echo ""

# ============================================
# STEP 3: Delete old EA log so we get fresh output
# ============================================
echo "--- STEP 3: Clean up ---"
# Delete state file
find /root/.wine -name "PropFirmBot_AccountState.dat" -delete 2>/dev/null
echo "State deleted"

# Rename today's log to see fresh entries clearly
LOG_FILE="${MT5_BASE}/MQL5/Logs/20260305.log"
if [ -f "$LOG_FILE" ]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
    echo "Old log renamed"
fi
echo ""

# ============================================
# STEP 4: Start MT5 fresh
# ============================================
echo "--- STEP 4: Start MT5 ---"
export DISPLAY=:99
export WINEPREFIX=/root/.wine

cd "$MT5_BASE"
nohup wine "$MT5_BASE/terminal64.exe" /portable > /tmp/mt5_stdout.log 2>&1 &
MT5_PID=$!
echo "MT5 PID: $MT5_PID"
echo "Waiting 45 seconds for full initialization..."
sleep 45

# ============================================
# STEP 5: FULL verification
# ============================================
echo ""
echo "========== FULL VERIFICATION =========="

echo "Wine processes:"
pgrep -a wineserver 2>/dev/null
echo ""

echo "MT5 stdout (if any errors):"
cat /tmp/mt5_stdout.log 2>/dev/null | tail -5
echo ""

echo "Network (FundedNext connected?):"
ss -tnp | grep "main\|wineserver" | head -5
echo ""

echo "Relay daemon:"
pgrep -a -f "telegram_relay" | head -1 || echo "NOT running - restarting..."
if ! pgrep -f "telegram_relay" > /dev/null; then
    nohup bash /root/telegram_relay.sh > /var/log/telegram_relay.log 2>&1 &
    sleep 2
    pgrep -f "telegram_relay" > /dev/null && echo "Relay restarted OK" || echo "Relay STILL failed"
fi
echo ""

echo "--- NEW EA Log ---"
NEW_LOG="${MT5_BASE}/MQL5/Logs/20260305.log"
if [ -f "$NEW_LOG" ]; then
    LOG_SIZE=$(stat -c%s "$NEW_LOG")
    echo "New log: $LOG_SIZE bytes"
    iconv -f UTF-16LE -t UTF-8 "$NEW_LOG" 2>/dev/null | head -50
else
    echo "No new log file yet!"
    echo "Available logs:"
    ls -la "${MT5_BASE}/MQL5/Logs/" 2>/dev/null | tail -10
fi
echo ""

echo "--- Status JSON ---"
cat "$FILES_DIR/status.json" 2>/dev/null | head -10
echo ""

echo "--- Telegram queue ---"
ls -la "$FILES_DIR/telegram_queue.txt" 2>/dev/null && echo "Content:" && cat "$FILES_DIR/telegram_queue.txt" 2>/dev/null | head -5
echo ""

echo "--- Relay log ---"
cat /var/log/telegram_relay.log 2>/dev/null | tail -5
echo ""

echo "=== DONE - $(date) ==="
