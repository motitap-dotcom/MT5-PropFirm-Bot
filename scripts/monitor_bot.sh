#!/bin/bash
# Bot health monitor - runs during trading hours
# Checks if bot is running, connected, and actively trading
cd /root/MT5-PropFirm-Bot

TIMESTAMP=$(date -u +'%Y-%m-%d %H:%M:%S UTC')
STATUS="OK"
DETAILS=""

# 1. Check service is running
SERVICE_STATE=$(systemctl is-active futures-bot 2>/dev/null || echo "not-found")
if [ "$SERVICE_STATE" != "active" ]; then
    STATUS="DOWN"
    DETAILS="Service: ${SERVICE_STATE}"

    # Auto-restart
    systemctl restart futures-bot 2>/dev/null
    sleep 10
    NEW_STATE=$(systemctl is-active futures-bot 2>/dev/null)
    DETAILS="${DETAILS} -> Restarted: ${NEW_STATE}"
fi

# 2. Check bot.log exists and was written recently (within last 10 min)
if [ -f logs/bot.log ]; then
    LAST_MOD=$(stat -c %Y logs/bot.log 2>/dev/null || echo 0)
    NOW=$(date +%s)
    AGE=$(( NOW - LAST_MOD ))
    if [ "$AGE" -gt 600 ]; then
        STATUS="STALE"
        DETAILS="${DETAILS} | Log not updated for ${AGE}s"
    fi

    # 3. Check for errors in last 20 lines
    ERRORS=$(tail -20 logs/bot.log | grep -c "ERROR\|CAPTCHA\|Fatal\|Max retries")
    if [ "$ERRORS" -gt 0 ]; then
        STATUS="ERROR"
        LAST_ERROR=$(tail -20 logs/bot.log | grep "ERROR\|CAPTCHA\|Fatal" | tail -1)
        DETAILS="${DETAILS} | Last error: ${LAST_ERROR}"
    fi

    # 4. Check if bot is in trading session or waiting
    LAST_LINES=$(tail -5 logs/bot.log)
    if echo "$LAST_LINES" | grep -q "Main loop"; then
        DETAILS="${DETAILS} | Bot is active in main loop"
    elif echo "$LAST_LINES" | grep -q "Outside trading session"; then
        DETAILS="${DETAILS} | Waiting for trading session"
    elif echo "$LAST_LINES" | grep -q "TRADE:"; then
        DETAILS="${DETAILS} | Bot is TRADING!"
    fi
else
    STATUS="NO_LOG"
    DETAILS="${DETAILS} | No bot.log found"
fi

# 5. Check status.json
if [ -f status/status.json ]; then
    GUARDIAN=$(python3 -c "import json; d=json.load(open('status/status.json')); print(d.get('guardian',{}).get('state','?'))" 2>/dev/null)
    BALANCE=$(python3 -c "import json; d=json.load(open('status/status.json')); print(d.get('guardian',{}).get('balance','?'))" 2>/dev/null)
    if [ -n "$GUARDIAN" ] && [ "$GUARDIAN" != "?" ]; then
        DETAILS="${DETAILS} | Guardian: ${GUARDIAN} | Balance: \$${BALANCE}"
    fi
fi

# Output for logging
echo "${TIMESTAMP} | Status: ${STATUS} | ${DETAILS}"

# Return status for Telegram
echo "BOT_STATUS=${STATUS}" > /tmp/bot_monitor_result.txt
echo "BOT_DETAILS=${DETAILS}" >> /tmp/bot_monitor_result.txt
echo "BOT_TIMESTAMP=${TIMESTAMP}" >> /tmp/bot_monitor_result.txt
