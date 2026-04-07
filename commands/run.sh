#!/bin/bash
# Trigger: v156
cd /root/MT5-PropFirm-Bot
echo "=== v156 $(date -u '+%Y-%m-%d %H:%M UTC') ==="
echo "Service: $(systemctl is-active futures-bot)"
echo "PID: $(systemctl show futures-bot --property=MainPID --value)"
echo "Code: $(git log -1 --oneline)"
echo ""
tail -60 logs/bot.log 2>/dev/null | grep -v "^$"
echo "=== END ==="
