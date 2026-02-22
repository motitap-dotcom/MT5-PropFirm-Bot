#!/bin/bash
###############################################
# PropFirmBot - Full VPS Setup & Health Check
# Just paste this into SSH and everything works
###############################################

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
CHAT_ID="7013213983"
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
EA_DIR="$MT5_DIR/MQL5/Experts/PropFirmBot"
LOGS_DIR="$MT5_DIR/MQL5/Logs"

send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "parse_mode=HTML" \
        -d "text=$1" > /dev/null 2>&1
}

echo "====================================="
echo "  PropFirmBot - Full Check & Setup"
echo "====================================="
echo ""

# 1. Check VNC
echo "[1/6] Checking VNC..."
if pgrep -x "Xvfb" > /dev/null && pgrep -x "x11vnc" > /dev/null; then
    echo "  ✅ VNC is running"
else
    echo "  ⚠️  VNC not running, starting..."
    pkill Xvfb 2>/dev/null; pkill x11vnc 2>/dev/null
    sleep 1
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw
    sleep 1
    if pgrep -x "Xvfb" > /dev/null; then
        echo "  ✅ VNC started"
    else
        echo "  ❌ VNC failed to start"
    fi
fi
export DISPLAY=:99

# 2. Check MT5
echo "[2/6] Checking MT5..."
if pgrep -f "terminal64.exe" > /dev/null; then
    echo "  ✅ MT5 is running"
else
    echo "  ⚠️  MT5 not running, starting..."
    cd "$MT5_DIR"
    wine terminal64.exe &
    sleep 15
    if pgrep -f "terminal64.exe" > /dev/null; then
        echo "  ✅ MT5 started"
    else
        echo "  ❌ MT5 failed to start"
    fi
fi

# 3. Check EA file exists
echo "[3/6] Checking EA files..."
if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
    SIZE=$(stat -c%s "$EA_DIR/PropFirmBot.ex5" 2>/dev/null || echo "0")
    echo "  ✅ PropFirmBot.ex5 exists (${SIZE} bytes)"
else
    echo "  ❌ PropFirmBot.ex5 NOT FOUND"
    echo "  Trying to compile..."
    if [ -f "$EA_DIR/PropFirmBot.mq5" ]; then
        cd "$MT5_DIR"
        wine metaeditor64.exe /compile:"MQL5/Experts/PropFirmBot/PropFirmBot.mq5" /log 2>/dev/null
        sleep 10
        if [ -f "$EA_DIR/PropFirmBot.ex5" ]; then
            echo "  ✅ Compiled successfully"
        else
            echo "  ❌ Compilation failed"
        fi
    fi
fi

# 4. Check MT5 logs for EA activity
echo "[4/6] Checking recent MT5 logs..."
LATEST_LOG=$(ls -t "$LOGS_DIR"/*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    echo "  Latest log: $(basename "$LATEST_LOG")"
    EA_LINES=$(grep -i "propfirm\|expert\|initialized\|trade" "$LATEST_LOG" 2>/dev/null | tail -5)
    if [ -n "$EA_LINES" ]; then
        echo "  ✅ EA activity found in logs:"
        echo "$EA_LINES" | while read line; do echo "    $line"; done
    else
        echo "  ⚠️  No EA activity in latest log"
    fi
else
    echo "  ⚠️  No log files found"
fi

# 5. Send Telegram test
echo "[5/6] Sending Telegram test..."
RESULT=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "parse_mode=HTML" \
    -d "text=🤖 <b>PropFirmBot Status Report</b>%0A%0A$(date '+%Y-%m-%d %H:%M:%S')%0A%0A✅ VPS: Online%0A✅ MT5: $(pgrep -f terminal64.exe > /dev/null && echo Running || echo Stopped)%0A✅ EA: $([ -f "$EA_DIR/PropFirmBot.ex5" ] && echo Installed || echo Missing)%0A%0AAccount: 11797849 (FundedNext)%0AServer: Stellar Instant $2,000")
if echo "$RESULT" | grep -q '"ok":true'; then
    echo "  ✅ Telegram message sent! Check your phone"
else
    echo "  ❌ Telegram failed: $RESULT"
fi

# 6. Setup watchdog (auto-restart MT5 if it crashes)
echo "[6/6] Setting up watchdog..."

cat > /root/mt5-watchdog.sh << 'WATCHDOG'
#!/bin/bash
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
CHAT_ID="7013213983"
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
export DISPLAY=:99

send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" -d "text=$1" > /dev/null 2>&1
}

# Check VNC
if ! pgrep -x "Xvfb" > /dev/null; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw
    send_telegram "⚠️ VNC was down - restarted"
fi

# Check MT5
if ! pgrep -f "terminal64.exe" > /dev/null; then
    cd "$MT5_DIR"
    wine terminal64.exe &
    sleep 15
    if pgrep -f "terminal64.exe" > /dev/null; then
        send_telegram "⚠️ MT5 was down - restarted successfully"
    else
        send_telegram "❌ MT5 is down and failed to restart!"
    fi
fi
WATCHDOG

chmod +x /root/mt5-watchdog.sh

# Add to crontab (every 5 minutes)
CRON_EXISTS=$(crontab -l 2>/dev/null | grep -c "mt5-watchdog")
if [ "$CRON_EXISTS" -eq 0 ]; then
    (crontab -l 2>/dev/null; echo "*/5 * * * * /root/mt5-watchdog.sh >> /root/watchdog.log 2>&1") | crontab -
    echo "  ✅ Watchdog installed (checks every 5 minutes)"
else
    echo "  ✅ Watchdog already installed"
fi

# Add startup on reboot
REBOOT_EXISTS=$(crontab -l 2>/dev/null | grep -c "@reboot.*mt5-watchdog")
if [ "$REBOOT_EXISTS" -eq 0 ]; then
    (crontab -l 2>/dev/null; echo "@reboot sleep 30 && /root/mt5-watchdog.sh >> /root/watchdog.log 2>&1") | crontab -
    echo "  ✅ Auto-start on reboot configured"
else
    echo "  ✅ Auto-start already configured"
fi

echo ""
echo "====================================="
echo "  ✅ DONE! Summary:"
echo "====================================="
echo "  VNC:      $(pgrep -x Xvfb > /dev/null && echo '✅ Running' || echo '❌ Down')"
echo "  MT5:      $(pgrep -f terminal64.exe > /dev/null && echo '✅ Running' || echo '❌ Down')"
echo "  EA:       $([ -f "$EA_DIR/PropFirmBot.ex5" ] && echo '✅ Installed' || echo '❌ Missing')"
echo "  Watchdog: ✅ Active (every 5 min)"
echo "  Reboot:   ✅ Auto-start configured"
echo "  Telegram: Check your phone for test message"
echo "====================================="
echo ""
echo "The bot is now monitored 24/7."
echo "If MT5 crashes, it restarts automatically."
echo "You'll get a Telegram alert if anything happens."
echo ""
