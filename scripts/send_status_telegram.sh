#!/bin/bash
#=============================================================================
# PropFirmBot - Quick Status to Telegram
# שולח סטטוס מהיר לטלגרם - הרצה פשוטה: bash send_status_telegram.sh
#=============================================================================

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
MT5="/root/.wine/drive_c/Program Files/MetaTrader 5"
TODAY=$(date '+%Y%m%d')

# Gather info
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null)
VNC_PID=$(pgrep -f "x11vnc" 2>/dev/null)
CONN=$(ss -tn state established 2>/dev/null | grep -v ":22 \|:5900 \|:53 " | grep -v "127.0.0.1" | wc -l)
CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{printf "%.0f", $2}')
RAM=$(free 2>/dev/null | awk '/Mem/{printf "%.0f", $3/$2*100}')

# MT5 status
if [ -n "$MT5_PID" ]; then
    MT5_STATUS="✅ Running (PID: $MT5_PID)"
    MT5_UPTIME=$(ps -p "$MT5_PID" -o etime= 2>/dev/null | xargs)
else
    MT5_STATUS="❌ NOT RUNNING"
    MT5_UPTIME="N/A"
fi

# VNC
if [ -n "$VNC_PID" ]; then
    VNC_STATUS="✅"
else
    VNC_STATUS="❌"
fi

# Broker
if [ "$CONN" -gt 0 ]; then
    BROKER_STATUS="✅ ($CONN conn)"
else
    BROKER_STATUS="❌ Disconnected"
fi

# Account data from status.json
STATUS_FILE="$MT5/MQL5/Files/PropFirmBot/status.json"
ACCT_INFO=""
if [ -f "$STATUS_FILE" ]; then
    BALANCE=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"balance": [0-9.]*' | head -1 | awk '{print $2}')
    EQUITY=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"equity": [0-9.]*' | head -1 | awk '{print $2}')
    GUARDIAN=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"state": "[^"]*"' | head -1 | awk -F'"' '{print $4}')
    TOTAL_DD=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"total_dd": [0-9.]*' | head -1 | awk '{print $2}')
    POS_COUNT=$(cat "$STATUS_FILE" | tr -d '\0' | grep -o '"count": [0-9]*' | head -1 | awk '{print $2}')
    AGE=$(( ($(date +%s) - $(stat -c%Y "$STATUS_FILE")) / 60 ))

    ACCT_INFO="
💰 Balance: \$${BALANCE}
💰 Equity: \$${EQUITY}
🛡 Guardian: ${GUARDIAN}
📉 DD: ${TOTAL_DD}%
📈 Positions: ${POS_COUNT}
📄 Updated: ${AGE} min ago"
fi

# EA activity
EA_LOG="$MT5/MQL5/Logs/${TODAY}.log"
if [ -f "$EA_LOG" ]; then
    EA_LINES=$(cat "$EA_LOG" | tr -d '\0' | wc -l)
    LAST_MSG=$(cat "$EA_LOG" | tr -d '\0' | tail -1 | head -c 100)
    EA_STATUS="✅ Active ($EA_LINES lines today)"
else
    EA_STATUS="⚠️ No log today"
    LAST_MSG=""
fi

# Build message
MSG="<b>🤖 PropFirmBot Quick Status</b>
<pre>$(date '+%d/%m/%Y %H:%M UTC')</pre>

<b>Services:</b>
MT5: ${MT5_STATUS}
VNC: ${VNC_STATUS} | Broker: ${BROKER_STATUS}
EA: ${EA_STATUS}
Uptime: ${MT5_UPTIME}
${ACCT_INFO}

<b>System:</b>
CPU: ${CPU}% | RAM: ${RAM}%

<b>Last EA msg:</b>
<pre>${LAST_MSG}</pre>"

# Send
RESULT=$(curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${MSG}" \
    -d "parse_mode=HTML" \
    2>&1)

if echo "$RESULT" | grep -q '"ok":true'; then
    echo "Status sent to Telegram!"
else
    echo "Failed to send. Response: $RESULT"
fi
