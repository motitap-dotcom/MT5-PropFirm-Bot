#!/bin/bash
#=============================================================================
# PropFirmBot - Telegram Real-Time Listener
# Monitors bot activity by listening to Telegram updates in real-time
# Usage on VPS: bash scripts/telegram_listener.sh
# Usage from Windows: ssh root@77.237.234.2 'bash /root/MT5-PropFirm-Bot/scripts/telegram_listener.sh'
# Press Ctrl+C to stop
#=============================================================================

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
LOG_DIR="$MT5_DIR/MQL5/Logs"

# Colors
G='\033[0;32m'
R='\033[0;31m'
Y='\033[1;33m'
C='\033[0;36m'
B='\033[1m'
N='\033[0m'

echo ""
echo -e "${C}╔══════════════════════════════════════════════╗${N}"
echo -e "${C}║  ${B}PropFirmBot - Real-Time Monitor${N}${C}             ║${N}"
echo -e "${C}║  Press Ctrl+C to stop                       ║${N}"
echo -e "${C}╚══════════════════════════════════════════════╝${N}"
echo ""

# Send start message
curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=👁️ מאזין פעיל - מתחיל מעקב בזמן אמת..." \
    > /dev/null 2>&1

LAST_LOG_LINE=0
LAST_HEARTBEAT=""
ITERATION=0

cleanup() {
    echo ""
    echo -e "${Y}Stopping listener...${N}"
    curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=👁️ מאזין הופסק" \
        > /dev/null 2>&1
    exit 0
}
trap cleanup SIGINT SIGTERM

while true; do
    ITERATION=$((ITERATION + 1))
    NOW=$(date '+%H:%M:%S')

    # --- Check MT5 Process ---
    MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null | head -1)
    if [ -z "$MT5_PID" ]; then
        echo -e "${R}[$NOW] ❌ MT5 NOT RUNNING!${N}"
    fi

    # --- Check EA Log for new entries ---
    LATEST_EA_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_EA_LOG" ]; then
        CURRENT_LINES=$(cat "$LATEST_EA_LOG" 2>/dev/null | tr -d '\0' | wc -l)

        if [ "$LAST_LOG_LINE" -eq 0 ]; then
            LAST_LOG_LINE=$CURRENT_LINES
            echo -e "${C}[$NOW] 📄 Tracking EA log: $(basename $LATEST_EA_LOG) ($CURRENT_LINES lines)${N}"
        fi

        if [ "$CURRENT_LINES" -gt "$LAST_LOG_LINE" ]; then
            NEW_LINES=$((CURRENT_LINES - LAST_LOG_LINE))
            echo -e "${G}[$NOW] 📥 $NEW_LINES new log entries:${N}"

            cat "$LATEST_EA_LOG" 2>/dev/null | tr -d '\0' | tail -n "$NEW_LINES" | while IFS= read -r line; do
                # Color based on content
                if echo "$line" | grep -qi "error\|fail\|critical"; then
                    echo -e "  ${R}$line${N}"
                elif echo "$line" | grep -qi "warn\|caution\|blocked"; then
                    echo -e "  ${Y}$line${N}"
                elif echo "$line" | grep -qi "trade\|order\|position\|closed"; then
                    echo -e "  ${G}${B}$line${N}"
                elif echo "$line" | grep -qi "heartbeat"; then
                    echo -e "  ${C}$line${N}"
                elif echo "$line" | grep -qi "signal"; then
                    echo -e "  ${G}$line${N}"
                else
                    echo -e "  $line"
                fi
            done

            LAST_LOG_LINE=$CURRENT_LINES
        fi
    fi

    # --- Every 30 iterations (~5 minutes), show status ---
    if [ $((ITERATION % 30)) -eq 0 ]; then
        echo ""
        echo -e "${C}[$NOW] ── Status Check ──${N}"
        echo -e "  MT5: $([ -n "$MT5_PID" ] && echo -e "${G}RUNNING (PID: $MT5_PID)${N}" || echo -e "${R}NOT RUNNING${N}")"
        echo -e "  VNC: $(pgrep x11vnc > /dev/null 2>&1 && echo -e "${G}RUNNING${N}" || echo -e "${R}NOT RUNNING${N}")"

        # Get latest heartbeat
        if [ -n "$LATEST_EA_LOG" ]; then
            HB=$(cat "$LATEST_EA_LOG" 2>/dev/null | tr -d '\0' | grep "\[HEARTBEAT\]" | tail -1)
            if [ -n "$HB" ]; then
                echo -e "  ${C}$HB${N}"
            fi
        fi

        # Broker connections
        CONN=$(ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | wc -l)
        echo -e "  Broker connections: $CONN"
        echo ""
    fi

    sleep 10
done
