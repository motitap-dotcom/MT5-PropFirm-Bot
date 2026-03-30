#!/bin/bash
# Trigger: v86 - Send status via Telegram directly from VPS
cd /root/MT5-PropFirm-Bot

# Write fresh .env from workflow secrets
if [ -n "$TRADOVATE_ACCESS_TOKEN" ]; then
    echo "TRADOVATE_USER=$TRADOVATE_USER" > .env
    echo "TRADOVATE_PASS=$TRADOVATE_PASS" >> .env
    echo "TRADOVATE_ACCESS_TOKEN=$TRADOVATE_ACCESS_TOKEN" >> .env
    echo "TELEGRAM_TOKEN=$TELEGRAM_TOKEN" >> .env
    echo "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID" >> .env
fi

rm -f configs/.tradovate_token.json
mkdir -p logs status

# Restart bot
systemctl stop futures-bot 2>/dev/null
sleep 3
systemctl daemon-reload
systemctl start futures-bot
sleep 15

# Collect status
STATUS=$(systemctl is-active futures-bot)
LOGS=$(journalctl -u futures-bot --no-pager -n 20 --since "20 sec ago" 2>&1)
BOTLOG=$(tail -15 logs/bot.log 2>/dev/null)

# Send to Telegram directly from VPS
MSG="🤖 Bot Status Report v86
━━━━━━━━━━━━━━━
Service: ${STATUS}
━━━━━━━━━━━━━━━
Journal:
${LOGS}
━━━━━━━━━━━━━━━
Bot Log:
${BOTLOG}"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_CHAT_ID}" \
  -d text="${MSG:0:4000}" \
  -d parse_mode="" > /dev/null 2>&1

echo "Status sent to Telegram"
