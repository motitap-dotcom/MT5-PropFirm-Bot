#!/bin/bash
# READ-ONLY status check - DO NOT restart or modify anything
cd /root/MT5-PropFirm-Bot
echo "Service: $(systemctl is-active futures-bot)"
echo "---LOG---"
tail -40 logs/bot.log 2>/dev/null || echo "No log"
echo "---JOURNAL---"
journalctl -u futures-bot --no-pager -n 10 2>&1
