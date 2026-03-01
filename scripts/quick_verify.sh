#!/bin/bash
#=============================================================================
# PropFirmBot - Quick Verify (30 seconds)
# Fast check: Is the bot alive? Send result to Telegram
# Usage: ssh root@77.237.234.2 'bash -s' < scripts/quick_verify.sh
#=============================================================================

TELEGRAM_TOKEN="8452836462:AAEVGDT5JrxOHAcB8Nd8ayObU1iMQUCRk2g"
TELEGRAM_CHAT_ID="7013213983"
MT5_DIR="/root/.wine/drive_c/Program Files/MetaTrader 5"
LOG_DIR="$MT5_DIR/MQL5/Logs"
NOW=$(date '+%d/%m/%Y %H:%M:%S')

# Quick checks
MT5_PID=$(pgrep -f "terminal64.exe" 2>/dev/null | head -1)
VNC_OK=$(pgrep x11vnc > /dev/null 2>&1 && echo "YES" || echo "NO")
XVFB_OK=$(pgrep Xvfb > /dev/null 2>&1 && echo "YES" || echo "NO")

# Get latest EA heartbeat
LATEST_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
HEARTBEAT=""
GUARDIAN=""
BALANCE=""
EQUITY=""
DD=""
POSITIONS=""

if [ -n "$LATEST_LOG" ]; then
    HB=$(cat "$LATEST_LOG" 2>/dev/null | tr -d '\0' | grep "\[HEARTBEAT\]" | tail -1)
    if [ -n "$HB" ]; then
        HEARTBEAT="YES"
        BALANCE=$(echo "$HB" | grep -oP 'Bal=\$[\d.]+' | sed 's/Bal=\$//')
        EQUITY=$(echo "$HB" | grep -oP 'Eq=\$[\d.]+' | sed 's/Eq=\$//')
        DD=$(echo "$HB" | grep -oP 'DD=[\d.]+' | sed 's/DD=//')
        POSITIONS=$(echo "$HB" | grep -oP 'Positions=\d+' | sed 's/Positions=//')
        GUARDIAN=$(echo "$HB" | grep -oP 'State=\w+' | sed 's/State=//')
    fi
fi

# Broker connection
TERM_LOG=$(ls -t "$MT5_DIR/logs"/*.log 2>/dev/null | head -1)
BROKER="UNKNOWN"
if [ -n "$TERM_LOG" ]; then
    LAST_AUTH=$(cat "$TERM_LOG" 2>/dev/null | tr -d '\0' | grep -E "authorized on|authorization.*failed" | tail -1)
    if echo "$LAST_AUTH" | grep -q "authorized on"; then
        BROKER="CONNECTED"
    elif echo "$LAST_AUTH" | grep -q "failed"; then
        BROKER="FAILED"
    fi
fi

# Print to console
echo "╔═══════════════════════════════════════╗"
echo "║  PropFirmBot Quick Verify - $NOW"
echo "╠═══════════════════════════════════════╣"
echo "║  MT5:      $([ -n "$MT5_PID" ] && echo "✅ RUNNING (PID: $MT5_PID)" || echo "❌ NOT RUNNING")"
echo "║  Broker:   $([ "$BROKER" = "CONNECTED" ] && echo "✅ CONNECTED" || echo "❌ $BROKER")"
echo "║  VNC:      $([ "$VNC_OK" = "YES" ] && echo "✅ RUNNING" || echo "❌ DOWN")"
echo "║  Guardian: ${GUARDIAN:-N/A}"
echo "║  Balance:  \$${BALANCE:-N/A}"
echo "║  Equity:   \$${EQUITY:-N/A}"
echo "║  DD:       ${DD:-0}%"
echo "║  Positions: ${POSITIONS:-0}"
echo "╚═══════════════════════════════════════╝"

# Determine status
if [ -n "$MT5_PID" ] && [ "$BROKER" = "CONNECTED" ]; then
    STATUS="🟢 הבוט חי ובועט!"
elif [ -n "$MT5_PID" ]; then
    STATUS="🟡 MT5 רץ אבל לא מחובר לברוקר"
else
    STATUS="🔴 MT5 לא פעיל!"
fi

# Send to Telegram
MSG="$STATUS

📊 בדיקה מהירה - $NOW
• MT5: $([ -n "$MT5_PID" ] && echo 'פעיל ✅' || echo 'לא פעיל ❌')
• ברוקר: $([ "$BROKER" = "CONNECTED" ] && echo 'מחובר ✅' || echo "$BROKER ❌")
• באלאנס: \$${BALANCE:-N/A}
• Equity: \$${EQUITY:-N/A}
• DD: ${DD:-0}%
• פוזיציות: ${POSITIONS:-0}
• Guardian: ${GUARDIAN:-N/A}"

curl -s "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${MSG}" \
    > /dev/null 2>&1

echo ""
echo "Status: $STATUS"
echo "Result sent to Telegram ✅"
