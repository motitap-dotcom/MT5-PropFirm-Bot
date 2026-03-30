#!/bin/bash
# Trigger: v64 - Restart with fixed workflows + check
cd /root/MT5-PropFirm-Bot
date -u

echo "---CLEAR-TOKEN---"
rm -f configs/.tradovate_token.json

echo "---RESTART---"
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
