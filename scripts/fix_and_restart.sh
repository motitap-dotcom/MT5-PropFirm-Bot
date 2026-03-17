#!/bin/bash
# PropFirmBot - Restart MT5 after EA deploy (v3 - code update)
# Triggered: 2026-03-17 - RiskManager trailing DD fix + input params update

echo "=== RESTART START $(date '+%Y-%m-%d %H:%M:%S UTC') ==="
echo "Reason: EA code updated - RiskManager DD fix + conservative inputs"

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# STEP 1: Fix DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
echo "1. DNS: FIXED"

# STEP 2: Fix time
ntpdate -u pool.ntp.org > /dev/null 2>&1 || true
echo "2. Time: $(date)"

# STEP 3: Stop MT5 gracefully
echo "3. Stopping MT5..."
pkill -f terminal64 2>/dev/null
sleep 3
pkill -9 -f terminal64 2>/dev/null
wineserver -k 2>/dev/null
sleep 2
echo "3. MT5: STOPPED"

# STEP 4: Ensure display
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
fi
export DISPLAY=:99
if ! pgrep -x x11vnc > /dev/null 2>&1; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
fi
echo "4. Display: OK"

# STEP 5: Configure MT5
mkdir -p "$MT5/config" 2>/dev/null
cat > "$MT5/config/common.ini" << 'EOF'
[Common]
Login=11797849
ProxyEnable=0
CertInstall=0
NewsEnable=0
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
EOF
echo "5. Config: WRITTEN"

# STEP 6: Start MT5 (fully detached)
export DISPLAY=:99
export WINEPREFIX=/root/.wine
cd "$MT5"
nohup wine terminal64.exe /portable /login:11797849 /password:gazDE62## /server:FundedNext-Server > /tmp/mt5_wine.log 2>&1 &
disown
echo "6. MT5: STARTING (backgrounded)"

# STEP 7: Wait briefly and check
sleep 15
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "7. MT5: RUNNING"
    ps aux | grep terminal64 | grep -v grep
else
    echo "7. MT5: NOT YET RUNNING (may still be loading)"
fi

# STEP 8: Check for new logs
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "8. Log: $(basename "$LATEST_LOG" 2>/dev/null) ($(stat -c%s "$LATEST_LOG") bytes)"
    cat "$LATEST_LOG" | tr -d '\0' | tail -20
else
    echo "8. Log: No logs yet"
fi

# STEP 9: Telegram
curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=🔧 MT5 Restarted on VPS $(date '+%H:%M UTC')
$(pgrep -f terminal64 > /dev/null 2>&1 && echo '✅ MT5 Running' || echo '⏳ MT5 Loading...')" > /dev/null 2>&1
echo "9. Telegram: SENT"

# STEP 10: Create a delayed check script (runs after 60 more seconds)
cat > /tmp/delayed_check.sh << 'DELAYED'
#!/bin/bash
sleep 60
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
BALANCE_LINE=""
if [ -n "$LATEST_LOG" ]; then
    BALANCE_LINE=$(cat "$LATEST_LOG" | tr -d '\0' | grep -i "balance\|INIT\|Account\|WARNING\|ERROR" | tail -5)
fi
MT5_OK=$(pgrep -f terminal64 > /dev/null 2>&1 && echo "RUNNING" || echo "DOWN")
curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=📊 60s Post-Restart Check:
MT5: $MT5_OK
Log: $BALANCE_LINE" > /dev/null 2>&1
DELAYED
chmod +x /tmp/delayed_check.sh
nohup bash /tmp/delayed_check.sh > /dev/null 2>&1 &
disown
echo "10. Delayed check: SCHEDULED (60s)"

echo "=== FIX DONE ==="
