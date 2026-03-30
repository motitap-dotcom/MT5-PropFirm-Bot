#!/bin/bash
# Trigger: v65
cd /root/MT5-PropFirm-Bot
date -u

# Update .env with env vars from GitHub Secrets (passed by workflow)
if [ -n "$TRADOVATE_ACCESS_TOKEN" ]; then
    echo "TRADOVATE_USER=$TRADOVATE_USER" > .env
    echo "TRADOVATE_PASS=$TRADOVATE_PASS" >> .env
    echo "TRADOVATE_ACCESS_TOKEN=$TRADOVATE_ACCESS_TOKEN" >> .env
    echo "TELEGRAM_TOKEN=$TELEGRAM_TOKEN" >> .env
    echo "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID" >> .env
    echo ".env updated from secrets"
fi

rm -f configs/.tradovate_token.json
systemctl stop futures-bot 2>/dev/null
sleep 2
systemctl daemon-reload
systemctl start futures-bot
sleep 10

echo "---STATUS---"
systemctl is-active futures-bot
echo "---LOGS---"
journalctl -u futures-bot --no-pager -n 25 --since "15 sec ago"
echo "---BOT-LOG---"
tail -20 logs/bot.log 2>/dev/null
echo "---DONE---"
