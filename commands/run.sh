#!/bin/bash
# Trigger: v126 - Status to Telegram (no restart, safe)
cd /root/MT5-PropFirm-Bot
source .env 2>/dev/null

STATUS=$(systemctl is-active futures-bot)
LOGS=$(tail -30 logs/bot.log 2>/dev/null || echo "No log")
JOURNAL=$(journalctl -u futures-bot --no-pager -n 5 2>&1)

echo "Service: $STATUS"
echo "$LOGS"
echo "$JOURNAL"

MSG="Bot Status v126
Service: ${STATUS}
$(date -u '+%Y-%m-%d %H:%M UTC')
---
${LOGS}
---
${JOURNAL}"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  -d text="${MSG:0:4000}" > /dev/null 2>&1
echo "Sent to Telegram"
