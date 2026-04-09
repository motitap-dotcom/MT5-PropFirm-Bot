#!/bin/bash
# Trigger: v165
cd /root/MT5-PropFirm-Bot
echo "=== CHECK v165 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo ""
tail -60 logs/bot.log 2>/dev/null
