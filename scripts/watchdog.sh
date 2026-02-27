#!/bin/bash
# PropFirmBot Watchdog - runs every 2 min via cron
# Checks MT5, auto-restarts if down, sends Telegram alerts

TG="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
CHAT="7013213983"
LOG="/root/PropFirmBot/logs/watchdog.log"
STATE="/root/PropFirmBot/state/mt5_status"
TS=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p /root/PropFirmBot/logs /root/PropFirmBot/state

PREV="unknown"
[ -f "$STATE" ] && PREV=$(cat "$STATE")

PID=$(pgrep -f terminal64.exe 2>/dev/null || true)

# Auto-restart VNC if down
pgrep -x x11vnc > /dev/null 2>&1 || (DISPLAY=:99 x11vnc -display :99 -forever -shared -rfbport 5900 -nopw -bg 2>/dev/null || true)

if [ -n "$PID" ]; then
    # MT5 is running
    if [ "$PREV" = "down" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TG}/sendMessage" \
            -d "chat_id=${CHAT}" \
            -d "text=PropFirmBot MT5 RECOVERED! PID:${PID} $(date '+%d/%m %H:%M')" > /dev/null 2>&1
        echo "$TS [RECOVERED] PID:$PID" >> "$LOG"
    fi
    echo "up" > "$STATE"
    # Log OK every ~15 min
    M=$(date '+%M')
    [ "$((M % 14))" -lt 2 ] && echo "$TS [OK] PID:$PID" >> "$LOG"
else
    # MT5 is DOWN - restart
    echo "$TS [ALERT] MT5 down! Restarting..." >> "$LOG"
    export DISPLAY=:99 WINEPREFIX=/root/.wine
    MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
    # Ensure correct servers.dat
    if [ $(stat -c%s "$MT5_DIR/config/servers.dat" 2>/dev/null || echo 0) -lt 60000 ]; then
        cp "$MT5_DIR/Config/servers.dat" "$MT5_DIR/config/servers.dat" 2>/dev/null
    fi
    cd "$MT5_DIR"
    nohup wine terminal64.exe "/config:C:\Program Files\MetaTrader 5\config\startup.ini" </dev/null >/dev/null 2>&1 &
    disown -a
    sleep 20
    NEW=$(pgrep -f terminal64.exe 2>/dev/null || true)
    if [ -n "$NEW" ]; then
        echo "up" > "$STATE"
        curl -s -X POST "https://api.telegram.org/bot${TG}/sendMessage" \
            -d "chat_id=${CHAT}" \
            -d "text=PropFirmBot MT5 RESTARTED! PID:${NEW} $(date '+%d/%m %H:%M')" > /dev/null 2>&1
        echo "$TS [RESTARTED] PID:$NEW" >> "$LOG"
    else
        echo "down" > "$STATE"
        curl -s -X POST "https://api.telegram.org/bot${TG}/sendMessage" \
            -d "chat_id=${CHAT}" \
            -d "text=PROPFIRMBOT MT5 DOWN! Restart FAILED! Check VPS: ssh root@77.237.234.2" > /dev/null 2>&1
        echo "$TS [ERROR] Restart failed!" >> "$LOG"
    fi
fi

# Keep log small
[ -f "$LOG" ] && tail -2000 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
