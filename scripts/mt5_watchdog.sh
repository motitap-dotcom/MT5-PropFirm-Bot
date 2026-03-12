#!/bin/bash
#=============================================================================
# MT5 Watchdog - Auto-restart MT5 if it crashes
# Install: crontab -e → */5 * * * * /root/MT5-PropFirm-Bot/scripts/mt5_watchdog.sh >> /var/log/mt5_watchdog.log 2>&1
#=============================================================================

MT5_BASE="/root/.wine/drive_c/Program Files/MetaTrader 5"
LOCKFILE="/tmp/mt5_watchdog.lock"
LOG_TAG="[MT5-WATCHDOG]"
TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT="7013213983"

# Prevent concurrent runs
if [ -f "$LOCKFILE" ]; then
    LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCKFILE") ))
    if [ "$LOCK_AGE" -lt 300 ]; then
        exit 0  # Another watchdog is still running
    fi
    rm -f "$LOCKFILE"  # Stale lock
fi
touch "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT

send_telegram() {
    curl -s -4 --connect-timeout 5 "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT}" \
        -d "text=$1" > /dev/null 2>&1 || true
}

# Check if MT5 is running
if pgrep -f "terminal64.exe" > /dev/null 2>&1; then
    # MT5 is running - check if EA is active (status.json updated in last 5 minutes)
    STATUS_FILE="${MT5_BASE}/MQL5/Files/PropFirmBot/status.json"
    if [ -f "$STATUS_FILE" ]; then
        FILE_AGE=$(( $(date +%s) - $(stat -c %Y "$STATUS_FILE") ))
        if [ "$FILE_AGE" -gt 300 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG WARNING: status.json is ${FILE_AGE}s old - EA may be stuck"
            send_telegram "⚠️ MT5 Watchdog: status.json not updated for ${FILE_AGE}s - EA may be stuck"
        fi
    fi
    exit 0
fi

# MT5 is NOT running - restart it
echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG MT5 is DOWN - restarting..."
send_telegram "🔴 MT5 Watchdog: MT5 is DOWN! Auto-restarting..."

# Ensure display is running
export DISPLAY=:99
export WINEPREFIX=/root/.wine

if ! pgrep -x Xvfb > /dev/null 2>&1; then
    Xvfb :99 -screen 0 1280x1024x24 &
    sleep 2
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG Started Xvfb"
fi

if ! pgrep -x x11vnc > /dev/null 2>&1; then
    x11vnc -display :99 -forever -shared -rfbport 5900 -bg -nopw 2>/dev/null
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG Started x11vnc"
fi

# Kill any zombie wine processes
wineserver -k 2>/dev/null
sleep 2

# Start MT5
cd "$MT5_BASE"
DISPLAY=:99 WINEPREFIX=/root/.wine nohup wine "$MT5_BASE/terminal64.exe" /portable > /dev/null 2>&1 &
disown

echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG MT5 start command issued"

# Wait and verify
sleep 20

if pgrep -f "terminal64.exe" > /dev/null 2>&1; then
    NEW_PID=$(pgrep -f "terminal64.exe" | head -1)
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG MT5 restarted successfully (PID=$NEW_PID)"
    send_telegram "✅ MT5 Watchdog: MT5 restarted successfully (PID=$NEW_PID)"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_TAG ERROR: MT5 failed to start!"
    send_telegram "❌ MT5 Watchdog: FAILED to restart MT5! Manual intervention needed."
fi
