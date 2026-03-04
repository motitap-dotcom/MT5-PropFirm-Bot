#!/bin/bash
# PropFirmBot Watchdog - Monitor MT5 and auto-restart if down
# Install as cron: */5 * * * * /root/MT5-PropFirm-Bot/scripts/watchdog.sh >> /var/log/watchdog.log 2>&1

MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
LOG="/var/log/watchdog.log"

send_telegram() {
    curl -s -4 --connect-timeout 10 "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=$1" \
        -d "parse_mode=HTML" > /dev/null 2>&1
}

echo "=== Watchdog $(date '+%Y-%m-%d %H:%M:%S UTC') ==="

# Check 1: Is MT5 running?
if ! pgrep -f terminal64 > /dev/null 2>&1; then
    echo "MT5 is DOWN - restarting..."
    send_telegram "⚠️ <b>Watchdog Alert</b>
MT5 is DOWN! Auto-restarting...
Time: $(date '+%H:%M UTC')"

    # Ensure display is running
    export DISPLAY=:99
    if ! pgrep -x Xvfb > /dev/null 2>&1; then
        Xvfb :99 -screen 0 1280x1024x24 &
        sleep 2
    fi
    if ! pgrep -x x11vnc > /dev/null 2>&1; then
        x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
        sleep 1
    fi

    # Clean old Wine processes
    wineserver -k 2>/dev/null
    sleep 2

    # Start MT5
    export WINEPREFIX=/root/.wine
    cd "$MT5"
    nohup wine terminal64.exe /login:11797849 /password:"gazDE62##" /server:FundedNext-Server > /tmp/mt5_wine.log 2>&1 &
    disown

    sleep 20

    if pgrep -f terminal64 > /dev/null 2>&1; then
        send_telegram "✅ <b>MT5 Restarted Successfully</b>
Time: $(date '+%H:%M UTC')"
        echo "MT5 restarted OK"
    else
        send_telegram "❌ <b>MT5 Restart FAILED</b>
Manual intervention needed!
VNC: 77.237.234.2:5900"
        echo "MT5 restart FAILED"
    fi
else
    echo "MT5 is running - OK"
fi

# Check 2: Is VNC running?
if ! pgrep -x x11vnc > /dev/null 2>&1; then
    echo "VNC is down - restarting..."
    export DISPLAY=:99
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    echo "VNC restarted"
fi

echo "=== Done ==="
