#!/bin/bash
# PropFirmBot Watchdog - runs via cron on VPS
# Checks MT5 status, restarts if needed, sends Telegram alerts
# Cron: */15 * * * * /root/MT5-PropFirm-Bot/scripts/watchdog.sh >> /var/log/propfirmbot_watchdog.log 2>&1

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT="7013213983"
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
LOCKFILE="/tmp/watchdog.lock"
LOGFILE="/var/log/propfirmbot_watchdog.log"

send_telegram() {
    local msg="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT}" \
        -d text="$msg" \
        -d parse_mode="HTML" > /dev/null 2>&1
}

# Prevent concurrent runs
if [ -f "$LOCKFILE" ]; then
    LOCK_AGE=$(( $(date +%s) - $(stat -c%Y "$LOCKFILE") ))
    if [ $LOCK_AGE -gt 300 ]; then
        rm -f "$LOCKFILE"
    else
        exit 0
    fi
fi
touch "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT

echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] Watchdog check"

# Check if MT5 is running
MT5_PID=$(ps aux | grep "terminal64.exe" | grep -v grep | awk '{print $2}' | head -1)

if [ -z "$MT5_PID" ]; then
    echo "MT5 NOT RUNNING - attempting restart..."
    send_telegram "⚠️ <b>PropFirmBot Watchdog</b>
MT5 is not running! Attempting restart..."

    # Ensure display server
    if ! pgrep -x Xvfb > /dev/null 2>&1; then
        Xvfb :99 -screen 0 1280x1024x24 &
        sleep 2
    fi
    if ! pgrep -x x11vnc > /dev/null 2>&1; then
        x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
        sleep 1
    fi

    # Start MT5
    export DISPLAY=:99
    export WINEPREFIX=/root/.wine
    nohup wine "$MT5/terminal64.exe" \
        /login:11797849 /password:gazDE62## /server:FundedNext-Server \
        > /dev/null 2>&1 &

    sleep 20

    # Verify restart
    if ps aux | grep "terminal64.exe" | grep -v grep > /dev/null; then
        send_telegram "✅ <b>PropFirmBot Watchdog</b>
MT5 restarted successfully!"
        echo "MT5 restarted OK"
    else
        send_telegram "🔴 <b>PropFirmBot Watchdog</b>
MT5 FAILED TO RESTART! Manual intervention needed."
        echo "MT5 RESTART FAILED!"
    fi
else
    echo "MT5 running (PID: $MT5_PID) - OK"
fi

# Check EA log for recent heartbeat (within last 20 minutes)
TODAY=$(date -u '+%Y%m%d')
EALOG="$MT5/MQL5/Logs/${TODAY}.log"
if [ -f "$EALOG" ]; then
    LAST_HB=$(tr -d '\0' < "$EALOG" | grep '\[HEARTBEAT\]' | tail -1)
    if [ -n "$LAST_HB" ]; then
        # Extract time from heartbeat log
        HB_TIME=$(echo "$LAST_HB" | grep -oP '\d{2}:\d{2}:\d{2}')
        NOW_TIME=$(date -u '+%H:%M:%S')
        echo "Last heartbeat: $HB_TIME (now: $NOW_TIME)"

        # Extract balance and equity from heartbeat
        BAL=$(echo "$LAST_HB" | grep -oP 'Bal=\$[\d.]+' | cut -d'$' -f2)
        EQ=$(echo "$LAST_HB" | grep -oP 'Eq=\$[\d.]+' | cut -d'$' -f2)
        DD=$(echo "$LAST_HB" | grep -oP 'DD=[\d.]+%' | cut -d'=' -f2)
        POS=$(echo "$LAST_HB" | grep -oP 'Positions=\d+' | cut -d'=' -f2)

        echo "Balance: $BAL | Equity: $EQ | DD: $DD | Positions: $POS"

        # Alert if DD is above 3.5% (soft limit)
        DD_NUM=$(echo "$DD" | tr -d '%')
        if [ -n "$DD_NUM" ] && [ "$(echo "$DD_NUM > 3.5" | bc 2>/dev/null)" = "1" ]; then
            send_telegram "🟡 <b>PropFirmBot Alert</b>
Drawdown warning: ${DD}
Balance: \$${BAL} | Equity: \$${EQ}
Positions: ${POS}"
        fi
    else
        echo "No heartbeat found in today's log"
    fi
else
    echo "No EA log for today"
fi
