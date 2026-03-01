#!/bin/bash
#=============================================================================
# PropFirmBot - Telegram Command Listener
# מאזין לפקודות מטלגרם ומגיב אוטומטית
# הפעלה: nohup bash telegram_listener.sh &
# עצירה: kill $(cat /tmp/tg_listener.pid)
#=============================================================================

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
OFFSET_FILE="/tmp/tg_listener_offset"
PID_FILE="/tmp/tg_listener.pid"
LOG_FILE="/root/PropFirmBot/logs/telegram_listener.log"

mkdir -p /root/PropFirmBot/logs

# Save PID
echo $$ > "$PID_FILE"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

send_telegram() {
    local message="$1"
    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=HTML" \
        > /dev/null 2>&1
}

get_status() {
    local MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null)
    local STATUS_FILE="$MT5/MQL5/Files/PropFirmBot/status.json"

    local msg="<b>📊 PropFirmBot Status</b>\n"
    msg+="<pre>$(date '+%d/%m/%Y %H:%M UTC')</pre>\n\n"

    # MT5 process
    if [ -n "$MT5_PID" ]; then
        local uptime=$(ps -p "$MT5_PID" -o etime= 2>/dev/null | xargs)
        msg+="✅ <b>MT5:</b> Running (PID: $MT5_PID)\n"
        msg+="⏱ Uptime: $uptime\n"
    else
        msg+="❌ <b>MT5:</b> NOT RUNNING!\n"
    fi

    # Broker connection
    local CONN=$(ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | grep -v "127.0.0.1" | wc -l)
    if [ "$CONN" -gt 0 ]; then
        msg+="✅ <b>Broker:</b> Connected ($CONN conn)\n"
    else
        msg+="❌ <b>Broker:</b> Not connected\n"
    fi

    # Account info from status.json
    if [ -f "$STATUS_FILE" ]; then
        local age=$(( ($(date +%s) - $(stat -c%Y "$STATUS_FILE")) / 60 ))
        local balance=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"balance": [0-9.]*' | head -1 | awk '{print $2}')
        local equity=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"equity": [0-9.]*' | head -1 | awk '{print $2}')
        local guardian=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"state": "[^"]*"' | head -1 | awk -F'"' '{print $4}')
        local total_dd=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"total_dd": [0-9.]*' | head -1 | awk '{print $2}')
        local pos_count=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"count": [0-9]*' | head -1 | awk '{print $2}')
        local can_trade=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"can_trade": [a-z]*' | head -1 | awk '{print $2}')

        msg+="\n💰 <b>Balance:</b> \$${balance}\n"
        msg+="💰 <b>Equity:</b> \$${equity}\n"
        msg+="🛡 <b>Guardian:</b> ${guardian}\n"
        msg+="📉 <b>Total DD:</b> ${total_dd}%\n"
        msg+="📈 <b>Open Positions:</b> ${pos_count}\n"
        msg+="🔄 <b>Can Trade:</b> ${can_trade}\n"
        msg+="📄 <b>Status age:</b> ${age} min\n"
    else
        msg+="\n⚠️ No status.json found\n"
    fi

    # System
    local cpu=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{printf "%.0f", $2}')
    local ram=$(free 2>/dev/null | awk '/Mem/{printf "%.0f", $3/$2*100}')
    msg+="\n💻 CPU: ${cpu}% | RAM: ${ram}%\n"

    echo -e "$msg"
}

get_logs() {
    local TODAY=$(date '+%Y%m%d')
    local EA_LOG="$MT5/MQL5/Logs/${TODAY}.log"
    local msg="<b>📋 EA Logs (Last 15 lines)</b>\n\n"

    if [ -f "$EA_LOG" ]; then
        local lines=$(cat "$EA_LOG" | tr -d '\0' | tail -15)
        msg+="<pre>$(echo "$lines" | head -c 3500)</pre>"
    else
        msg+="No EA log for today ($TODAY)"
    fi

    echo -e "$msg"
}

get_trades() {
    local STATUS_FILE="$MT5/MQL5/Files/PropFirmBot/status.json"
    local msg="<b>📈 Open Trades</b>\n\n"

    if [ -f "$STATUS_FILE" ]; then
        local positions=$(cat "$STATUS_FILE" | tr -d '\0' | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    positions = data.get('positions', {}).get('open', [])
    if not positions:
        print('No open positions')
    else:
        for p in positions:
            emoji = '🟢' if p.get('profit', 0) >= 0 else '🔴'
            print(f\"{emoji} {p.get('type','?')} {p.get('symbol','?')} {p.get('volume',0)} lots\")
            print(f\"   Entry: {p.get('open_price',0)} → Current: {p.get('current_price',0)}\")
            print(f\"   PnL: \${p.get('profit',0):.2f} ({p.get('pips',0):.1f} pips)\")
            print(f\"   SL: {p.get('sl',0)} | TP: {p.get('tp',0)}\")
            print()
except:
    print('Could not parse status.json')
" 2>/dev/null)
        msg+="<pre>$positions</pre>"
    else
        msg+="No status data available"
    fi

    echo -e "$msg"
}

restart_mt5() {
    local msg="<b>🔄 Restarting MT5...</b>\n\n"

    pkill -f terminal64 2>/dev/null
    sleep 3
    pkill -9 -f terminal64 2>/dev/null
    sleep 2

    export DISPLAY=:99
    export WINEPREFIX=/root/.wine
    cd "$MT5"
    nohup wine terminal64.exe > /tmp/mt5_restart.log 2>&1 &
    disown
    sleep 15

    local NEW_PID=$(pgrep -f "terminal64.exe" 2>/dev/null)
    if [ -n "$NEW_PID" ]; then
        msg+="✅ MT5 restarted successfully (PID: $NEW_PID)"
    else
        msg+="❌ MT5 restart FAILED! Check VNC."
    fi

    echo -e "$msg"
}

show_help() {
    echo "<b>🤖 PropFirmBot - Available Commands</b>

<b>/status</b> - Full bot status
<b>/logs</b> - Last 15 EA log lines
<b>/trades</b> - Open positions
<b>/restart</b> - Restart MT5
<b>/health</b> - Full health check
<b>/help</b> - Show this message

Just type any command in this chat!"
}

# =============================================
# MAIN LOOP
# =============================================

# Get initial offset
if [ -f "$OFFSET_FILE" ]; then
    OFFSET=$(cat "$OFFSET_FILE")
else
    # Start fresh - get current offset
    LATEST=$(curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getUpdates?limit=1&offset=-1" 2>/dev/null)
    OFFSET=$(echo "$LATEST" | grep -o '"update_id":[0-9]*' | head -1 | awk -F: '{print $2}')
    if [ -n "$OFFSET" ]; then
        OFFSET=$((OFFSET + 1))
    else
        OFFSET=0
    fi
    echo "$OFFSET" > "$OFFSET_FILE"
fi

log "Listener started (PID: $$, offset: $OFFSET)"
send_telegram "🟢 <b>PropFirmBot Listener Active!</b>

I'm now listening for commands.
Type <b>/help</b> to see available commands."

echo "PropFirmBot Telegram Listener started (PID: $$)"
echo "Listening for commands... Press Ctrl+C to stop."

while true; do
    # Poll for updates
    UPDATES=$(curl -s --connect-timeout 10 \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/getUpdates?offset=${OFFSET}&timeout=30" \
        2>/dev/null)

    if [ -z "$UPDATES" ]; then
        sleep 5
        continue
    fi

    # Process each update
    echo "$UPDATES" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('ok') and data.get('result'):
        for update in data['result']:
            uid = update['update_id']
            msg = update.get('message', {})
            text = msg.get('text', '')
            chat_id = str(msg.get('chat', {}).get('id', ''))
            print(f'{uid}|{chat_id}|{text}')
except:
    pass
" 2>/dev/null | while IFS='|' read -r UPDATE_ID CHAT_ID TEXT; do

        # Only respond to our chat
        if [ "$CHAT_ID" != "$TELEGRAM_CHAT_ID" ]; then
            OFFSET=$((UPDATE_ID + 1))
            echo "$OFFSET" > "$OFFSET_FILE"
            continue
        fi

        log "Received: $TEXT"

        case "$TEXT" in
            /status|/status@*)
                RESPONSE=$(get_status)
                send_telegram "$RESPONSE"
                ;;
            /logs|/logs@*)
                RESPONSE=$(get_logs)
                send_telegram "$RESPONSE"
                ;;
            /trades|/trades@*)
                RESPONSE=$(get_trades)
                send_telegram "$RESPONSE"
                ;;
            /restart|/restart@*)
                send_telegram "⏳ Restarting MT5... please wait 20 seconds"
                RESPONSE=$(restart_mt5)
                send_telegram "$RESPONSE"
                ;;
            /health|/health@*)
                send_telegram "⏳ Running full health check..."
                bash /root/MT5-PropFirm-Bot/scripts/verify_bot_live.sh > /dev/null 2>&1
                ;;
            /help|/help@*|/start|/start@*)
                RESPONSE=$(show_help)
                send_telegram "$RESPONSE"
                ;;
            *)
                if [[ "$TEXT" == /* ]]; then
                    send_telegram "❓ Unknown command: $TEXT\nType /help for available commands."
                fi
                ;;
        esac

        OFFSET=$((UPDATE_ID + 1))
        echo "$OFFSET" > "$OFFSET_FILE"
    done

    # Small delay between polls
    sleep 1
done
