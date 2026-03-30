#!/bin/bash
# Trigger: v63
cd /root/MT5-PropFirm-Bot
date -u
echo "---GIT-LOG---"
git log --oneline -3
echo "---STATUS---"
systemctl is-active futures-bot
echo "---JOURNAL---"
journalctl -u futures-bot --no-pager -n 30 --since "5 min ago"
echo "---BOT-LOG---"
tail -25 logs/bot.log 2>/dev/null
echo "---DONE---"
