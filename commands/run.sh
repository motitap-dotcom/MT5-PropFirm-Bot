#!/bin/bash
# READ-ONLY status check v132
cd /root/MT5-PropFirm-Bot
echo "Service: $(systemctl is-active futures-bot)"
echo "---JOURNAL LAST 20---"
journalctl -u futures-bot --no-pager -n 20 2>&1
echo "---BOT LOG LAST 10---"
tail -10 logs/bot.log 2>/dev/null
