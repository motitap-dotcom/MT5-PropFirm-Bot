#!/bin/bash
# Trigger: v81
cd /root/MT5-PropFirm-Bot
date -u

# Write fresh .env from workflow secrets
if [ -n "$TRADOVATE_ACCESS_TOKEN" ]; then
    echo "TRADOVATE_USER=$TRADOVATE_USER" > .env
    echo "TRADOVATE_PASS=$TRADOVATE_PASS" >> .env
    echo "TRADOVATE_ACCESS_TOKEN=$TRADOVATE_ACCESS_TOKEN" >> .env
    echo "TELEGRAM_TOKEN=$TELEGRAM_TOKEN" >> .env
    echo "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID" >> .env
    echo ".env updated"
fi

rm -f configs/.tradovate_token.json
mkdir -p logs status

systemctl stop futures-bot 2>/dev/null
sleep 3
systemctl daemon-reload
systemctl start futures-bot
sleep 12

echo "---STATUS---"
systemctl is-active futures-bot
echo "---LOGS---"
journalctl -u futures-bot --no-pager -n 30 --since "20 sec ago"
echo "---BOT-LOG---"
tail -20 logs/bot.log 2>/dev/null
echo "---DONE---"
