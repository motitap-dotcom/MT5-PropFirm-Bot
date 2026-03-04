#!/bin/bash
# =============================================================
# START MT5 + PropFirmBot on VPS
# Triggered: 2026-03-04
# =============================================================

echo "=== STARTING BOT $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"

# STEP 1: Fix DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
echo "1. DNS: FIXED"

# STEP 2: Fix time
ntpdate -u pool.ntp.org > /dev/null 2>&1 || true
echo "2. Time: $(date)"

# STEP 3: Stop any existing MT5
pkill -f terminal64 2>/dev/null
sleep 3
pkill -9 -f terminal64 2>/dev/null
wineserver -k 2>/dev/null
sleep 2
echo "3. Old MT5: STOPPED"

# STEP 4: Ensure display (Xvfb + VNC)
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
    echo "4a. Xvfb: STARTED"
else
    echo "4a. Xvfb: ALREADY RUNNING"
fi
export DISPLAY=:99

if ! pgrep -x x11vnc > /dev/null 2>&1; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    echo "4b. VNC: STARTED"
else
    echo "4b. VNC: ALREADY RUNNING"
fi

# STEP 5: Update EA files from repo
cd /root/MT5-PropFirm-Bot 2>/dev/null
git fetch origin 2>/dev/null
git checkout claude/deploy-bot-server-vDXK7 2>/dev/null || git checkout claude/build-cfd-trading-bot-fl0ld 2>/dev/null
git pull 2>/dev/null
EA_DIR="$MT5/MQL5/Experts/PropFirmBot"
mkdir -p "$EA_DIR"
if [ -d "EA" ] && ls EA/*.mq5 EA/*.mqh 2>/dev/null | head -1 > /dev/null; then
    cp EA/*.mq5 EA/*.mqh "$EA_DIR/" 2>/dev/null
    echo "5. EA files: UPDATED from repo"
else
    echo "5. EA files: USING EXISTING (no EA dir in current branch)"
fi

# STEP 6: Compile EA
cd "$MT5"
export WINEPREFIX=/root/.wine
export DISPLAY=:99
wine metaeditor64.exe /compile:MQL5/Experts/PropFirmBot/PropFirmBot.mq5 /log 2>/dev/null
sleep 8
if [ -f "MQL5/Experts/PropFirmBot/PropFirmBot.ex5" ]; then
    echo "6. EA: COMPILED ($(stat -c%s "MQL5/Experts/PropFirmBot/PropFirmBot.ex5") bytes)"
else
    echo "6. EA: Using existing .ex5 (compilation may have failed)"
fi

# STEP 7: Configure MT5 for auto-login and EA
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
echo "7. MT5 Config: WRITTEN"

# STEP 8: Start MT5 with login
cd "$MT5"
export DISPLAY=:99
export WINEPREFIX=/root/.wine
nohup wine terminal64.exe /portable /login:11797849 /password:gazDE62## /server:FundedNext-Server > /tmp/mt5_wine.log 2>&1 &
disown
echo "8. MT5: STARTING..."

# STEP 9: Wait and verify
sleep 20
if pgrep -f terminal64 > /dev/null 2>&1; then
    echo "9. MT5: RUNNING ✅"
    ps aux | grep terminal64 | grep -v grep
else
    echo "9. MT5: NOT YET RUNNING (may still be loading)"
    echo "Wine log:"
    tail -10 /tmp/mt5_wine.log 2>/dev/null
fi

# STEP 10: Check logs
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "10. Latest log: $(basename "$LATEST_LOG")"
    cat "$LATEST_LOG" | tr -d '\0' | tail -20
else
    echo "10. No logs yet (MT5 may still be loading)"
fi

# STEP 11: Telegram notification
curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=🚀 Bot Started on VPS $(date '+%H:%M UTC')
$(pgrep -f terminal64 > /dev/null 2>&1 && echo '✅ MT5 Running' || echo '⏳ MT5 Loading...')
Account: 11797849 | EURUSD M15" > /dev/null 2>&1
echo "11. Telegram: SENT"

# STEP 12: Schedule delayed check (60s later)
cat > /tmp/delayed_check.sh << 'DELAYED'
#!/bin/bash
sleep 60
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
LATEST_LOG=$(ls -t "$MT5/MQL5/Logs/"*.log 2>/dev/null | head -1)
LOG_INFO=""
if [ -n "$LATEST_LOG" ]; then
    LOG_INFO=$(cat "$LATEST_LOG" | tr -d '\0' | grep -i "balance\|INIT\|Account\|WARNING\|ERROR\|expert\|PropFirm" | tail -5)
fi
MT5_STATUS=$(pgrep -f terminal64 > /dev/null 2>&1 && echo "✅ RUNNING" || echo "❌ DOWN")
curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g/sendMessage" \
    -d "chat_id=7013213983" \
    -d "text=📊 60s Post-Start Check:
MT5: $MT5_STATUS
Log: $LOG_INFO" > /dev/null 2>&1
DELAYED
chmod +x /tmp/delayed_check.sh
nohup bash /tmp/delayed_check.sh > /dev/null 2>&1 &
disown
echo "12. Delayed check: SCHEDULED (60s)"

echo ""
echo "=== DONE ==="
