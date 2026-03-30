#!/bin/bash
# Trigger: v85
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

systemctl stop futures-bot 2>/dev/null
sleep 3
systemctl daemon-reload
systemctl start futures-bot
