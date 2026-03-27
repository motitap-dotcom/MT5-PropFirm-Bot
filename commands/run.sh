#!/bin/bash
# Trigger: v53
cd /root/MT5-PropFirm-Bot
mkdir -p status logs
date -u
systemctl is-active futures-bot
journalctl -u futures-bot --no-pager -n 40 --since "10 min ago"
echo "---"
tail -5 logs/bot.log
